# 启动任务编排调度器设计

## 目标

将 AppDelegate 中 11 个 SDK 的串行初始化改为基于 DAG（有向无环图）的并行调度，支持四种触发时机、失败策略与超时机制，采用回调式调度避免线程池耗尽，压缩启动耗时。

## 架构

```
┌─────────────────────────────────────────────┐
│  AppDelegate                                │
│  scheduler.registerAll() + scheduler.start()│
├─────────────────────────────────────────────┤
│  LaunchScheduler（核心调度器）                 │
│  - 任务注册（TaskName / deps / trigger /      │
│    timeout / failurePolicy / block）         │
│  - DAG 环检测（DFS）                          │
│  - 统一派发条件：activated && inDegree==0      │
│  - 回调式调度（入度递减 → 归零派发）              │
│  - 失败策略（strict 级联 / tolerant 容错）      │
│  - 超时监控（DispatchWorkItem 定时器）          │
│  - GCD 并发队列执行，NSLock 保护状态             │
│  - 与 LaunchMetrics 自动集成                   │
├─────────────────────────────────────────────┤
│  触发层                                       │
│  - start() → syncAtStart（同步等待）            │
│           → asyncAtStart（异步不阻塞）          │
│  - RunLoop beforeWaiting → afterFirstFrame    │
│  - fire("event") → onEvent 任务               │
├─────────────────────────────────────────────┤
│  LaunchMetrics（微调）                         │
│  - observeFirstFrame 回调中触发 afterFirstFrame│
│  - NSLock 保护 marks 数组线程安全               │
│  - 每个任务执行前后自动 mark                     │
└─────────────────────────────────────────────┘
```

### 文件结构

| 文件 | 动作 | 职责 |
|------|------|------|
| `WeChatSwift/LaunchScheduler.swift` | 新建 | 调度器核心 + 任务注册（同一文件，MARK 分区） |
| `WeChatSwift/AppDelegate.swift` | 修改 | 用 registerAll + start 替代手动串行调用 |
| `WeChatSwift/LaunchMetrics.swift` | 微调 | observeFirstFrame 中触发 startAfterFirstFrame；marks 加锁 |
| `WeChatSwift/MockSDKs.swift` | 不改动 | SDK 实现不变 |

## 数据模型

```swift
enum TaskName: String, Hashable {
    case crashSDK       = "CrashSDK"
    case deviceIDSDK    = "DeviceIDSDK"
    case configSDK      = "ConfigSDK"
    case analyticsSDK   = "AnalyticsSDK"
    case pushSDK        = "PushSDK"
    case abTestSDK      = "ABTestSDK"
    case shareSDK       = "ShareSDK"
    case mapSDK         = "MapSDK"
    case adSDK          = "AdSDK"
    case paySDK         = "PaySDK"
    case arSDK          = "ARSDK"
}

enum TaskTrigger: Equatable {
    case syncAtStart        // start() 同步等待完成
    case asyncAtStart       // start() 时异步执行，不阻塞返回
    case afterFirstFrame    // 首屏渲染完成后触发
    case onEvent(String)    // 等待指定业务事件
}

enum FailurePolicy {
    case strict     // 失败级联：下游也标记 failed，不执行
    case tolerant   // 容错：下游照常跑，自行兜底
}

private enum TaskState {
    case pending
    case running
    case done
    case failed
}

private struct LaunchTask {
    let name: TaskName
    let deps: [TaskName]
    let trigger: TaskTrigger
    let timeout: TimeInterval
    let failurePolicy: FailurePolicy
    let block: () throws -> Void
}
```

### TaskName 枚举的价值

- 编译期检查拼写错误（`deps: [.deviceIDSDK]` 比 `deps: ["DeviceIDSDK"]` 安全）
- IDE 自动补全
- 重命名时编译器报错所有引用处
- `rawValue` 用于 LaunchMetrics 打点输出

## 调度模型：回调式（非阻塞）

### 为什么不用 DispatchGroup.wait

阻塞式调度中，每个有依赖的任务占一个线程 `wait` 上游完成。任务量大时（几十个 SDK）会打满 GCD 线程池（默认 64 线程），导致线程饥饿和死锁风险。

### 回调式调度原理

```
注册时：
  - inDegree[name] = deps.count    （未完成依赖数）
  - downstream[dep] += [name]       （反向邻接表）

派发时（统一条件）：
  - activated && inDegree == 0 && pending → dispatchTask
  - 任务执行完毕 → onTaskFinished 回调：
    1. 标记 done / failed
    2. 遍历 downstream，递减下游 inDegree
    3. 调用 dispatchReadyTasks(among: downstream) 检查就绪任务
    4. syncAtStart 任务额外 syncGroup.leave()
```

每个任务只在真正可执行时才 dispatch 到并发队列，零线程阻塞等待。

### 统一派发入口

所有触发路径都收敛到同一个方法：

```swift
private func dispatchReadyTasks(among candidates: [TaskName]) {
    // 统一条件：activated && inDegree == 0 && pending
}
```

| 调用方 | candidates 来源 |
|--------|----------------|
| `start()` | syncAtStart + asyncAtStart 任务名 |
| `startAfterFirstFrame()` | afterFirstFrame 任务名 |
| `fire()` | 所有已激活的任务名 |
| `onTaskFinished()` | 下游任务名（downstream） |

这意味着 onEvent 任务也可以声明跨阶段依赖（如 `deps: [.deviceIDSDK]`），fire 时如果依赖已完成（inDegree 已归零），直接派发；如果未完成，`activateDeps` 递归激活依赖链先跑完再触发。

### 核心数据结构

```swift
final class LaunchScheduler {
    static let shared = LaunchScheduler()

    private let concurrentQueue = DispatchQueue(label: "launch.scheduler", attributes: .concurrent)
    private let lock = NSLock()

    private var tasks: [TaskName: LaunchTask] = [:]
    private var state: [TaskName: TaskState] = [:]
    private var inDegree: [TaskName: Int] = [:]            // 剩余未完成的依赖数
    private var downstream: [TaskName: [TaskName]] = [:]   // dep → [dependents]
    private var activated: Set<TaskName> = []               // 已激活的任务
    private let syncGroup = DispatchGroup()                // 仅等待 syncAtStart 任务
}
```

## 失败处理

### 失败策略

| 策略 | 行为 | 适用场景 |
|------|------|---------|
| `.strict` | 依赖失败 → 下游级联标记 failed，跳过执行 | 关键链路（DeviceID → Analytics → ABTest） |
| `.tolerant` | 依赖失败 → 下游照常执行，自行兜底 | 非核心功能（Push、Share、Ad） |

### 级联失败流程

```
dispatchTask(name):
    检查 deps 中是否有 strict 且 failed 的依赖
    → 有：标记 failed，打印日志，走 onTaskFinished(succeeded: false)
    → 无：正常执行
```

### 超时机制

```
dispatchTask(name):
    1. asyncAfter(timeout) → handleTimeout → 标记 failed → onTaskFinished
    2. concurrentQueue.async → 执行 block → 成功则 cancel 超时定时器
    3. 如果超时先触发，block 完成后检查 alreadyFailed，避免重复回调
```

默认超时 5 秒。注册时可自定义：`timeout: 10.0`。

### syncGroup 安全

`onTaskFinished` 中无论成功失败都调用 `syncGroup.leave()`，确保 `start()` 的 `syncGroup.wait()` 不会死锁。

## 调度流程

### 四阶段触发

```
scheduler.start()
    ↓
激活 syncAtStart + asyncAtStart → dispatchReadyTasks
    ↓ 回调链：完成 → 递减下游入度 → 归零派发
    ↓ syncGroup.wait() 只等 syncAtStart
    ↓ asyncAtStart 在后台继续，不阻塞
    ↓
首屏 RunLoop beforeWaiting 触发
    ↓
激活 afterFirstFrame → dispatchReadyTasks
    ↓
业务方调用 fire("enterMapPage")
    ↓
激活 onEvent 任务 + 递归激活依赖链 → dispatchReadyTasks
```

### 单任务执行流程

```
dispatchTask(name):
    lock → 检查 pending → 检查 strict 依赖失败 → 标记 running → unlock
    启动超时定时器
    concurrentQueue.async {
        LaunchMetrics.trackSDK(name) { try block() }
        cancel 超时定时器
        if !alreadyFailed → onTaskFinished(succeeded)
    }

onTaskFinished(task, succeeded):
    lock → 标记 done/failed → 递减 downstream inDegree → unlock
    if syncAtStart → syncGroup.leave()
    dispatchReadyTasks(among: downstream)
```

## 环检测

`start()` 内部先执行 DFS 环检测。遍历所有任务节点，维护 visiting / visited 状态：

- 遇到 visiting 节点 → 发现环 → fatalError 报错，防止死锁
- 所有节点都 visited → 无环，继续调度

## 任务注册

同文件 extension，集中管理：

```swift
extension LaunchScheduler {
    func registerAll() {
        // 第一梯队：syncAtStart，无依赖，必须最早完成
        register(.crashSDK,    deps: [], trigger: .syncAtStart) { CrashSDK.setup() }
        register(.deviceIDSDK, deps: [], trigger: .syncAtStart) { DeviceIDSDK.setup() }
        register(.configSDK,   deps: [], trigger: .syncAtStart) { ConfigSDK.setup() }

        // 第二梯队：有依赖
        register(.analyticsSDK, deps: [.deviceIDSDK], trigger: .syncAtStart) { AnalyticsSDK.setup() }
        register(.pushSDK,      deps: [.deviceIDSDK], trigger: .asyncAtStart, failurePolicy: .tolerant) { PushSDK.setup() }
        register(.abTestSDK,    deps: [.analyticsSDK, .configSDK], trigger: .syncAtStart) { ABTestSDK.setup() }
        register(.shareSDK,     deps: [.deviceIDSDK], trigger: .asyncAtStart, failurePolicy: .tolerant) { ShareSDK.setup() }

        // 第三梯队：延迟触发
        register(.mapSDK, deps: [], trigger: .onEvent("enterMapPage"), failurePolicy: .tolerant) { MapSDK.setup() }
        register(.adSDK,  deps: [], trigger: .afterFirstFrame, failurePolicy: .tolerant) { AdSDK.setup() }
        register(.paySDK, deps: [], trigger: .onEvent("enterPayPage")) { PaySDK.setup() }
        register(.arSDK,  deps: [], trigger: .afterFirstFrame, failurePolicy: .tolerant) { ARSDK.setup() }
    }
}
```

### 任务分类依据

| 任务 | 触发类型 | 失败策略 | 理由 |
|------|---------|---------|------|
| CrashSDK | syncAtStart | strict | 崩溃监控必须最早就绪 |
| DeviceIDSDK | syncAtStart | strict | 下游 Analytics/ABTest 依赖 |
| ConfigSDK | syncAtStart | strict | ABTest 依赖 |
| AnalyticsSDK | syncAtStart | strict | ABTest 依赖 |
| ABTestSDK | syncAtStart | strict | 首屏可能需要实验配置 |
| PushSDK | asyncAtStart | tolerant | 推送注册可后台完成 |
| ShareSDK | asyncAtStart | tolerant | 分享不影响首屏 |
| MapSDK | onEvent | tolerant | 进入地图页才初始化 |
| AdSDK | afterFirstFrame | tolerant | 首屏后加载广告 |
| PaySDK | onEvent | strict | 支付流程不能容错 |
| ARSDK | afterFirstFrame | tolerant | 首屏后加载 AR |

## AppDelegate 集成

```swift
func didFinishLaunchingWithOptions(...) -> Bool {
    LaunchMetrics.mark("didFinishStart")

    // ── 原有 RN 初始化 ──
    RNFactoryManager.shared.setup()
    ...

    // ── SDK 并行调度 ──
    LaunchScheduler.shared.registerAll()
    LaunchScheduler.shared.start()

    // ── 路由注册 ──
    ...

    LaunchMetrics.mark("didFinishEnd")
    LaunchMetrics.observeFirstFrame()
    return true
}
```

## 依赖关系图

```
syncAtStart 阶段（start 同步等待）:

CrashSDK ──────────────────────────────── (独立)
DeviceIDSDK ──┬── AnalyticsSDK ──┐
              │                  ├── ABTestSDK
              │                  │
ConfigSDK ───────────────────────┘

asyncAtStart 阶段（start 异步不阻塞）:

DeviceIDSDK ──┬── PushSDK   [tolerant]
              └── ShareSDK  [tolerant]

afterFirstFrame 阶段:

AdSDK ──── (独立) [tolerant]
ARSDK ──── (独立) [tolerant]

onEvent 阶段:

MapSDK ──── fire("enterMapPage") [tolerant]
PaySDK ──── fire("enterPayPage") [strict]
```

## 性能预估

### 串行（优化前）

全部 11 个 SDK 串行：~1020-1700ms（实测 ~1511ms）

### 并行后

**syncAtStart 关键路径**（start() 阻塞等待）：

DeviceIDSDK(50-80) → AnalyticsSDK(80-150) → ABTestSDK(100-200) ≈ 230-430ms
ConfigSDK(60-100) 并行，ABTestSDK 等两者都完成才启动。
CrashSDK 在关键路径内并行完成。

**start() 阻塞耗时预估：~300-430ms**（优化 70%+）

**asyncAtStart**（PushSDK + ShareSDK）：不阻塞 start()，在后台完成。

**afterFirstFrame + onEvent**：不占启动时间，按需触发。

## 线程安全

| 组件 | 保护机制 |
|------|---------|
| LaunchScheduler 共享状态 | NSLock（tasks/state/inDegree/downstream/activated） |
| LaunchMetrics.marks 数组 | NSLock（并发 trackSDK 写入安全） |
| LaunchMetrics.mark() 时间戳 | 锁外取值 `CFAbsoluteTimeGetCurrent()`，锁内 append（保证时间准确） |

## 与 LaunchMetrics 的衔接

- 调度器在每个任务执行时自动调用 `LaunchMetrics.trackSDK(name.rawValue) { try block() }`
- 报告中 SDK Details 自动体现并行效果（各 SDK 的绝对耗时不变，但总耗时大幅下降）
- `start()` 同步等待 syncAtStart 完成后返回，`didFinishStart → didFinishEnd` 区间准确反映同步 SDK 初始化耗时
- `observeFirstFrame` 回调中调用 `LaunchScheduler.shared.startAfterFirstFrame()` 触发延迟任务
