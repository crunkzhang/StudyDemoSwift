# 启动任务编排调度器设计

## 目标

将 AppDelegate 中 11 个 SDK 的串行初始化改为基于 DAG（有向无环图）的并行调度，支持三种触发时机（立即 / 首屏后 / 业务事件），压缩启动耗时。

## 架构

```
┌─────────────────────────────────────────────┐
│  AppDelegate                                │
│  scheduler.registerAll() + scheduler.start()│
├─────────────────────────────────────────────┤
│  LaunchScheduler（核心调度器）                 │
│  - 任务注册（name / deps / trigger / block）  │
│  - DAG 环检测（DFS）                          │
│  - 三种触发时机调度                             │
│  - GCD 并发队列 + DispatchGroup 依赖等待       │
│  - 与 LaunchMetrics 自动集成                   │
├─────────────────────────────────────────────┤
│  触发层                                       │
│  - start() → immediate 任务                   │
│  - RunLoop beforeWaiting → afterFirstFrame    │
│  - fire("event") → onEvent 任务               │
├─────────────────────────────────────────────┤
│  LaunchMetrics（已有，不改动）                   │
│  - 每个任务执行前后自动 mark                     │
└─────────────────────────────────────────────┘
```

### 文件结构

| 文件 | 动作 | 职责 |
|------|------|------|
| `WeChatSwift/LaunchScheduler.swift` | 新建 | 调度器核心 + 任务注册（同一文件，MARK 分区） |
| `WeChatSwift/AppDelegate.swift` | 修改 | 用 registerAll + start 替代手动串行调用 |
| `WeChatSwift/LaunchMetrics.swift` | 不改动 | 调度器内部调用 trackSDK |
| `WeChatSwift/MockSDKs.swift` | 不改动 | SDK 实现不变 |

## 数据模型

```swift
enum TaskTrigger {
    case immediate          // start() 时立即执行
    case afterFirstFrame    // 首屏渲染完成后自动触发
    case onEvent(String)    // 等待指定业务事件
}

enum TaskState {
    case pending
    case running
    case done
}

struct LaunchTask {
    let name: String
    let deps: [String]
    let trigger: TaskTrigger
    let block: () -> Void
}
```

## 调度流程

### 三阶段触发

```
scheduler.start()
    ↓
筛选 trigger == .immediate 的任务
    ↓ 拓扑调度，入度为 0 的并行 dispatch
    ↓ 每个任务完成后检查下游入度，归零则 dispatch
    ↓
首屏 RunLoop beforeWaiting 触发
    ↓
筛选 trigger == .afterFirstFrame 的任务
    ↓ 同样走拓扑调度（依赖可能已被 immediate 阶段完成）
    ↓
业务方调用 fire("enterMapPage")
    ↓
筛选 trigger == .onEvent("enterMapPage") 的任务
    ↓ 检查依赖，未完成的自动先执行
```

### 单任务执行流程

```
dispatch to concurrent queue {
    1. 等待所有依赖完成（deps 的 DispatchGroup.wait）
    2. 标记 running
    3. LaunchMetrics.trackSDK(name) { block() }
    4. 标记 done，completionGroup.leave() 释放下游
}
```

### 关键约束

- 每个任务只执行一次，通过 TaskState 防止重复
- 跨阶段依赖自动处理：afterFirstFrame 任务依赖的 immediate 任务已完成则直接执行
- fire 触发时如果依赖链有未执行任务，递归向上触发

## 并发实现

```swift
final class LaunchScheduler {
    static let shared = LaunchScheduler()

    private let queue = DispatchQueue(label: "launch.scheduler", attributes: .concurrent)
    private var tasks: [String: LaunchTask] = [:]
    private var taskState: [String: TaskState] = [:]
    private var completionGroups: [String: DispatchGroup] = [:]
}
```

- 并发队列：所有任务 dispatch 到同一个 concurrent queue
- DispatchGroup：每个任务一个 group，注册时 enter()，完成时 leave()
- 依赖等待：下游任务在并发队列线程上 wait 上游的 group，不阻塞其他任务

## 环检测

`start()` 内部先执行 DFS 环检测。遍历所有任务节点，维护 visiting / visited 状态：

- 遇到 visiting 节点 → 发现环 → fatalError 报错，防止死锁
- 所有节点都 visited → 无环，继续调度

## 任务注册

同文件 extension，集中管理：

```swift
// MARK: - Task Registration

extension LaunchScheduler {
    func registerAll() {
        // 第一梯队：immediate，无依赖
        register("CrashSDK",    deps: [], trigger: .immediate) { CrashSDK.setup() }
        register("DeviceIDSDK", deps: [], trigger: .immediate) { DeviceIDSDK.setup() }
        register("ConfigSDK",   deps: [], trigger: .immediate) { ConfigSDK.setup() }

        // 第二梯队：immediate，有依赖
        register("AnalyticsSDK", deps: ["DeviceIDSDK"], trigger: .immediate) { AnalyticsSDK.setup() }
        register("PushSDK",      deps: ["DeviceIDSDK"], trigger: .immediate) { PushSDK.setup() }
        register("ABTestSDK",    deps: ["AnalyticsSDK", "ConfigSDK"], trigger: .immediate) { ABTestSDK.setup() }
        register("ShareSDK",     deps: ["DeviceIDSDK"], trigger: .immediate) { ShareSDK.setup() }

        // 第三梯队：延迟触发
        register("MapSDK",  deps: [], trigger: .onEvent("enterMapPage")) { MapSDK.setup() }
        register("AdSDK",   deps: [], trigger: .afterFirstFrame) { AdSDK.setup() }
        register("PaySDK",  deps: [], trigger: .onEvent("enterPayPage")) { PaySDK.setup() }
        register("ARSDK",   deps: [], trigger: .afterFirstFrame) { ARSDK.setup() }
    }
}
```

## AppDelegate 集成

```swift
func didFinishLaunchingWithOptions(...) -> Bool {
    LaunchMetrics.mark("didFinishStart")

    LaunchScheduler.shared.registerAll()
    LaunchScheduler.shared.start()

    // 路由注册...

    LaunchMetrics.mark("didFinishEnd")
    return true
}
```

## 依赖关系图

```
immediate 阶段:

CrashSDK ──────────────────────────────── (独立)
DeviceIDSDK ──┬── AnalyticsSDK ──┐
              ├── PushSDK        ├── ABTestSDK
              └── ShareSDK       │
ConfigSDK ───────────────────────┘

afterFirstFrame 阶段:

AdSDK ──── (独立)
ARSDK ──── (独立)

onEvent 阶段:

MapSDK ──── fire("enterMapPage")
PaySDK ──── fire("enterPayPage")
```

## 性能预估

### 串行（当前）

全部 11 个 SDK 串行：~1020-1700ms（实测 ~1511ms）

### 并行后（immediate 阶段）

关键路径：DeviceIDSDK(50-80) → AnalyticsSDK(80-150) → ABTestSDK(100-200) ≈ 230-430ms

同时 ConfigSDK(60-100) 并行，ABTestSDK 等两者都完成才启动。

CrashSDK、PushSDK、ShareSDK 在关键路径内并行完成。

**immediate 阶段预估：~300-430ms**（从 ~1511ms 压缩，优化 70%+）

### 延迟任务

MapSDK / PaySDK / AdSDK / ARSDK 不占启动时间，按需触发。

## 与 LaunchMetrics 的衔接

- 调度器在每个任务执行时自动调用 `LaunchMetrics.trackSDK(name) { block() }`
- 报告中 SDK Details 自动体现并行效果（各 SDK 的绝对耗时不变，但总耗时大幅下降）
- immediate 阶段的 `start()` 需要同步等待所有 immediate 任务完成后返回，这样 `didFinishStart → didFinishEnd` 的区间仍然能准确反映 SDK 初始化总耗时
