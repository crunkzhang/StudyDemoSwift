import Foundation
import WeChatRN
import ChatModule
import ContactModule
import DiscoverModule
import MeModule

// MARK: - Data Model

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
    case routeSetup     = "RouteSetup"
    case rnBundle       = "RNBundle"
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

// MARK: - LaunchScheduler

final class LaunchScheduler {

    static let shared = LaunchScheduler()

    private let concurrentQueue = DispatchQueue(label: "launch.scheduler", attributes: .concurrent)
    private let lock = NSLock()

    private var tasks: [TaskName: LaunchTask] = [:]
    private var state: [TaskName: TaskState] = [:]
    private var inDegree: [TaskName: Int] = [:]            // 剩余未完成的依赖数
    private var downstream: [TaskName: [TaskName]] = [:]   // dep → [dependents]
    private var activated: Set<TaskName> = []              // 已激活（触发阶段已到达）的任务
    private let syncGroup = DispatchGroup()                // 仅等待 syncAtStart 任务

    private init() {}

    // MARK: - Register

    func register(
        _ name: TaskName,
        deps: [TaskName] = [],
        trigger: TaskTrigger = .syncAtStart,
        timeout: TimeInterval = 5.0,
        failurePolicy: FailurePolicy = .strict,
        block: @escaping () throws -> Void
    ) {
        tasks[name] = LaunchTask(
            name: name, deps: deps, trigger: trigger,
            timeout: timeout, failurePolicy: failurePolicy, block: block
        )
        state[name] = .pending
        inDegree[name] = deps.count

        // 构建反向邻接表
        for dep in deps {
            downstream[dep, default: []].append(name)
        }
    }

    // MARK: - Cycle Detection

    private func detectCycle() {
        enum Visit { case unvisited, visiting, visited }
        var visits: [TaskName: Visit] = [:]
        for name in tasks.keys { visits[name] = .unvisited }

        func dfs(_ name: TaskName) {
            guard let visit = visits[name] else { return }
            if visit == .visiting {
                fatalError("LaunchScheduler: cycle detected at '\(name.rawValue)'")
            }
            if visit == .visited { return }
            visits[name] = .visiting
            for dep in tasks[name]?.deps ?? [] { dfs(dep) }
            visits[name] = .visited
        }

        for name in tasks.keys where visits[name] == .unvisited {
            dfs(name)
        }
    }

    // MARK: - Callback-Based Dispatch

    /// 派发单个任务到并发队列
    private func dispatchTask(_ name: TaskName) {
        lock.lock()
        guard let task = tasks[name], state[name] == .pending else {
            lock.unlock()
            return
        }

        // 检查是否有 strict 依赖已失败 → 级联失败
        let hasFailedStrictDep = task.deps.contains { dep in
            state[dep] == .failed && tasks[dep]?.failurePolicy == .strict
        }
        if hasFailedStrictDep {
            state[name] = .failed
            lock.unlock()
            print("[LaunchScheduler] ⚠️ \(name.rawValue) skipped: strict dependency failed")
            onTaskFinished(task, succeeded: false)
            return
        }

        state[name] = .running
        lock.unlock()

        // 超时监控
        let timeoutItem = DispatchWorkItem { [weak self] in
            self?.handleTimeout(task)
        }
        concurrentQueue.asyncAfter(deadline: .now() + task.timeout, execute: timeoutItem)

        // 执行任务
        concurrentQueue.async {
            var succeeded = true
            LaunchMetrics.trackSDK(task.name.rawValue) {
                do {
                    try task.block()
                } catch {
                    succeeded = false
                    print("[LaunchScheduler] ❌ \(task.name.rawValue) failed: \(error)")
                }
            }
            timeoutItem.cancel()

            self.lock.lock()
            // 可能已被超时标记为 failed
            let alreadyFailed = self.state[task.name] == .failed
            self.lock.unlock()

            if !alreadyFailed {
                self.onTaskFinished(task, succeeded: succeeded)
            }
        }
    }

    /// 超时处理
    private func handleTimeout(_ task: LaunchTask) {
        lock.lock()
        guard state[task.name] == .running else {
            lock.unlock()
            return
        }
        state[task.name] = .failed
        lock.unlock()

        print("[LaunchScheduler] ⏰ \(task.name.rawValue) timed out after \(task.timeout)s")
        onTaskFinished(task, succeeded: false)
    }

    /// 任务结束回调（成功或失败均走此路径）
    private func onTaskFinished(_ task: LaunchTask, succeeded: Bool) {
        lock.lock()
        if succeeded {
            state[task.name] = .done
        } else if state[task.name] != .failed {
            state[task.name] = .failed
        }

        // 递减下游入度
        let candidates = downstream[task.name] ?? []
        for name in candidates {
            inDegree[name]! -= 1
        }
        lock.unlock()

        // syncAtStart 任务结束时释放 syncGroup（无论成功失败都要释放，否则死锁）
        if task.trigger == .syncAtStart {
            syncGroup.leave()
        }

        // 统一检查下游就绪任务
        dispatchReadyTasks(among: candidates)
    }

    // MARK: - Unified Dispatch

    /// 统一派发条件：activated && inDegree == 0 && pending
    private func dispatchReadyTasks(among candidates: [TaskName]) {
        lock.lock()
        let ready = candidates.filter {
            activated.contains($0) && inDegree[$0] == 0 && state[$0] == .pending
        }
        lock.unlock()

        for name in ready {
            dispatchTask(name)
        }
    }

    // MARK: - Trigger Methods

    /// 启动调度：派发 syncAtStart + asyncAtStart，同步等待 syncAtStart 完成
    func start() {
        detectCycle()

        lock.lock()
        let startTasks = tasks.values.filter {
            $0.trigger == .syncAtStart || $0.trigger == .asyncAtStart
        }

        for task in startTasks {
            activated.insert(task.name)
            if task.trigger == .syncAtStart {
                syncGroup.enter()
            }
        }
        let candidates = startTasks.map { $0.name }
        lock.unlock()

        dispatchReadyTasks(among: candidates)
        syncGroup.wait()
    }

    /// 首屏渲染完成后触发 afterFirstFrame 任务
    func startAfterFirstFrame() {
        lock.lock()
        let afterTasks = tasks.values.filter { $0.trigger == .afterFirstFrame }
        for task in afterTasks {
            activated.insert(task.name)
        }
        let candidates = afterTasks.map { $0.name }
        lock.unlock()

        dispatchReadyTasks(among: candidates)
    }

    /// 业务事件触发
    func fire(_ event: String) {
        lock.lock()
        let eventTasks = tasks.values.filter { $0.trigger == .onEvent(event) }
        for task in eventTasks {
            activated.insert(task.name)
            activateDeps(for: task)
        }
        let candidates = Array(activated)
        lock.unlock()

        dispatchReadyTasks(among: candidates)
    }

    /// 递归激活依赖链（确保 fire 时上游任务也被激活）
    private func activateDeps(for task: LaunchTask) {
        for dep in task.deps {
            guard let depTask = tasks[dep], !activated.contains(dep) else { continue }
            activated.insert(dep)
            activateDeps(for: depTask)
        }
    }
}

// MARK: - Task Registration

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

        // 路由注册：syncAtStart，首帧渲染前必须完成。
        // 五个模块打包进同一个 task，避免并发写 Router.routes 字典。
        register(.routeSetup, deps: [], trigger: .syncAtStart) {
            RNBaseViewController.registerPageRoute()
            ChatModule.registerRoutes()
            ContactModule.registerRoutes()
            DiscoverModule.registerRoutes()
            MeModule.registerRoutes()
        }

        // RN Bundle 热更新：afterFirstFrame，延迟到首帧后再做网络检查，不占启动窗口。
        // CatonMonitor / RNFactoryManager 需主线程初始化，保留在 AppDelegate 内联调用。
        register(.rnBundle, deps: [], trigger: .afterFirstFrame, failurePolicy: .tolerant) {
            RNBundleManager.shared.configure(
                remoteURL: "https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com",
                appVersion: "1.0.0"
            )
            RNBundleManager.shared.start()
        }
    }
}
