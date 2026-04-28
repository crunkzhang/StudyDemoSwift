# 启动任务编排调度器 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 11 个 SDK 的串行初始化改为基于 DAG 的并行调度，支持三种触发时机（immediate / afterFirstFrame / onEvent），将 SDK init 耗时从 ~1511ms 压缩到 ~400ms。

**Architecture:** LaunchScheduler 单例持有任务注册表，start() 对 immediate 任务做 DFS 环检测后按拓扑并行 dispatch 到 GCD concurrent queue，每个任务通过 DispatchGroup 等待依赖完成。afterFirstFrame 通过 RunLoop observer 触发，onEvent 通过 fire() 触发。

**Tech Stack:** Swift, GCD (DispatchQueue, DispatchGroup), CFRunLoop

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `WeChatSwift/LaunchScheduler.swift` | Create | 数据模型 + 调度器核心 + 任务注册 |
| `WeChatSwift/AppDelegate.swift` | Modify | 用 registerAll + start 替代手动串行调用 |
| `WeChatSwift/LaunchMetrics.swift` | Modify (微调) | observeFirstFrame 改为触发 afterFirstFrame 任务 |

---

### Task 1: 数据模型 + LaunchScheduler 骨架

**Files:**
- Create: `WeChatSwift/LaunchScheduler.swift`

- [ ] **Step 1: 创建 LaunchScheduler.swift — 数据模型 + 骨架**

```swift
import Foundation

// MARK: - Data Model

enum TaskTrigger: Equatable {
    case immediate
    case afterFirstFrame
    case onEvent(String)
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

// MARK: - LaunchScheduler

final class LaunchScheduler {

    static let shared = LaunchScheduler()

    private let queue = DispatchQueue(label: "launch.scheduler", attributes: .concurrent)
    private var tasks: [String: LaunchTask] = [:]
    private var state: [String: TaskState] = [:]
    private var groups: [String: DispatchGroup] = [:]

    private init() {}

    // MARK: - Register

    func register(
        _ name: String,
        deps: [String] = [],
        trigger: TaskTrigger = .immediate,
        block: @escaping () -> Void
    ) {
        let task = LaunchTask(name: name, deps: deps, trigger: trigger, block: block)
        tasks[name] = task
        state[name] = .pending
        let group = DispatchGroup()
        group.enter()
        groups[name] = group
    }
}
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'generic/platform=iOS' build 2>&1 | grep -E "error:|BUILD" | tail -5`
Expected: BUILD SUCCEEDED

---

### Task 2: DAG 环检测

**Files:**
- Modify: `WeChatSwift/LaunchScheduler.swift`

- [ ] **Step 1: 添加 DFS 环检测方法**

在 `LaunchScheduler` class 内、`register` 方法之后添加：

```swift
    // MARK: - Cycle Detection

    private func detectCycle() {
        enum Visit { case unvisited, visiting, visited }
        var visits: [String: Visit] = [:]
        for name in tasks.keys { visits[name] = .unvisited }

        func dfs(_ name: String) {
            guard let visit = visits[name] else { return }
            if visit == .visiting {
                fatalError("LaunchScheduler: cycle detected at task '\(name)'")
            }
            if visit == .visited { return }
            visits[name] = .visiting
            for dep in tasks[name]?.deps ?? [] {
                dfs(dep)
            }
            visits[name] = .visited
        }

        for name in tasks.keys {
            if visits[name] == .unvisited {
                dfs(name)
            }
        }
    }
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'generic/platform=iOS' build 2>&1 | grep -E "error:|BUILD" | tail -5`
Expected: BUILD SUCCEEDED

---

### Task 3: 核心调度 — executeTask + start

**Files:**
- Modify: `WeChatSwift/LaunchScheduler.swift`

- [ ] **Step 1: 添加 executeTask 方法**

在 `detectCycle()` 方法之后添加：

```swift
    // MARK: - Execution

    private func executeTask(_ name: String) {
        guard let task = tasks[name], state[name] == .pending else { return }
        state[name] = .running

        queue.async {
            // 等待所有依赖完成
            for dep in task.deps {
                self.groups[dep]?.wait()
            }

            // 执行任务（自动打点）
            LaunchMetrics.trackSDK(task.name) {
                task.block()
            }

            // 标记完成，释放下游
            self.state[name] = .done
            self.groups[name]?.leave()
        }
    }
```

- [ ] **Step 2: 添加 start 方法**

在 `executeTask` 方法之后添加：

```swift
    func start() {
        detectCycle()

        // 调度所有 immediate 任务
        let immediateTasks = tasks.values.filter { $0.trigger == .immediate }
        let group = DispatchGroup()
        for task in immediateTasks {
            group.enter()
            executeTask(task.name)
            // 监听完成
            queue.async {
                self.groups[task.name]?.wait()
                group.leave()
            }
        }
        // 同步等待所有 immediate 任务完成
        group.wait()
    }
```

- [ ] **Step 3: 编译验证**

Run: `xcodebuild -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'generic/platform=iOS' build 2>&1 | grep -E "error:|BUILD" | tail -5`
Expected: BUILD SUCCEEDED

---

### Task 4: afterFirstFrame + fire 触发

**Files:**
- Modify: `WeChatSwift/LaunchScheduler.swift`

- [ ] **Step 1: 添加 startAfterFirstFrame 方法**

在 `start()` 方法之后添加：

```swift
    func startAfterFirstFrame() {
        let afterTasks = tasks.values.filter { $0.trigger == .afterFirstFrame }
        for task in afterTasks {
            executeTask(task.name)
        }
    }

    func fire(_ event: String) {
        let eventTasks = tasks.values.filter { $0.trigger == .onEvent(event) }
        for task in eventTasks {
            // 如果有依赖未执行，递归触发依赖链
            ensureDeps(for: task)
            executeTask(task.name)
        }
    }

    private func ensureDeps(for task: LaunchTask) {
        for dep in task.deps {
            guard let depTask = tasks[dep], state[dep] == .pending else { continue }
            ensureDeps(for: depTask)
            executeTask(dep)
        }
    }
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'generic/platform=iOS' build 2>&1 | grep -E "error:|BUILD" | tail -5`
Expected: BUILD SUCCEEDED

---

### Task 5: 任务注册清单

**Files:**
- Modify: `WeChatSwift/LaunchScheduler.swift`

- [ ] **Step 1: 在文件底部添加 registerAll 扩展**

在文件末尾添加：

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

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'generic/platform=iOS' build 2>&1 | grep -E "error:|BUILD" | tail -5`
Expected: BUILD SUCCEEDED

---

### Task 6: AppDelegate 集成 + LaunchMetrics 衔接

**Files:**
- Modify: `WeChatSwift/AppDelegate.swift`
- Modify: `WeChatSwift/LaunchMetrics.swift`

- [ ] **Step 1: 修改 LaunchMetrics.observeFirstFrame — 触发 afterFirstFrame 任务**

将 `LaunchMetrics.swift` 中 `observeFirstFrame()` 方法的 observer 回调改为：

```swift
    static func observeFirstFrame() {
        let observer = CFRunLoopObserverCreateWithHandler(
            kCFAllocatorDefault,
            CFRunLoopActivity.beforeWaiting.rawValue,
            true,
            Int.max
        ) { observer, _ in
            CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, .commonModes)
            mark("firstFrame")
            // 触发 afterFirstFrame 阶段的延迟任务
            LaunchScheduler.shared.startAfterFirstFrame()
            report()
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
    }
```

- [ ] **Step 2: 重写 AppDelegate.didFinishLaunchingWithOptions**

将 `AppDelegate.swift` 中 `didFinishLaunchingWithOptions` 方法的完整内容替换为：

```swift
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        LaunchMetrics.mark("didFinishStart")

        // ── 原有 RN 初始化 ──
        RNFactoryManager.shared.setup()
        RNBundleManager.shared.configure(
            remoteURL: "https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com",
            appVersion: "1.0.0"
        )
        RNBundleManager.shared.start()

        // ── SDK 并行调度 ──
        LaunchScheduler.shared.registerAll()
        LaunchScheduler.shared.start()

        // ── 路由注册 ──
        RNBaseViewController.registerPageRoute()
        ChatModule.registerRoutes()
        ContactModule.registerRoutes()
        DiscoverModule.registerRoutes()
        MeModule.registerRoutes()

        LaunchMetrics.mark("didFinishEnd")
        LaunchMetrics.observeFirstFrame()
        return true
    }
```

- [ ] **Step 3: 编译验证**

Run: `xcodebuild -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'generic/platform=iOS' build 2>&1 | grep -E "error:|BUILD" | tail -5`
Expected: BUILD SUCCEEDED

---

### Task 7: 真机运行验证

**Files:** 无文件变更，纯验证

- [ ] **Step 1: 真机运行**

在 Xcode 中选择真机设备，Run（Cmd+R）。

- [ ] **Step 2: 检查控制台输出**

在 Xcode Console 中搜索 "Launch Metrics Report"，验证：

1. SDK init 总耗时应从 ~1511ms 下降到 ~300-430ms
2. 各 SDK 的单项耗时应与之前一致（各自的 sleep 没变）
3. 第三梯队 SDK（AdSDK / ARSDK）应出现在 firstFrame 之后
4. 报告格式与之前一致

预期输出示例（immediate 部分）：

```
║ Phase Breakdown:                                 ║
║   SDK init            :   380ms                  ║
```

- [ ] **Step 3: 验证 fire 触发**

在需要触发 MapSDK 的页面入口添加测试代码：

```swift
LaunchScheduler.shared.fire("enterMapPage")
```

控制台应出现 `sdk_MapSDK_start` 和 `sdk_MapSDK_end` 打点。
