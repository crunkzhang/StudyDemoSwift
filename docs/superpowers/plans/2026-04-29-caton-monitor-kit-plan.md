# CatonMonitorKit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Foundation 层构建管道式卡顿检测框架 CatonMonitorKit，覆盖 RunLoop/FPS/Watchdog 三种检测手段，含堆栈采集、本地存储、上报协议和 Debug 浮窗。

**Architecture:** 管道式架构——Detector(采集) → CatonEvent(数据模型) → StackCapture(堆栈) → CatonDiskStore(存储) → Reporter(上报)。CatonMonitor 作为协调者管理管道生命周期。所有检测在子线程完成，不阻塞主线程。

**Tech Stack:** Swift 5.0, UIKit, Mach API (thread_get_state), CFRunLoop, CADisplayLink, Codable/JSON

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `Foundation/CatonMonitorKit/CatonMonitorKit.podspec` | Create | Pod 定义 |
| `Foundation/CatonMonitorKit/Core/CatonEvent.swift` | Create | 卡顿事件数据模型 + CatonType + ThreadInfo |
| `Foundation/CatonMonitorKit/Core/CatonConfig.swift` | Create | 配置（阈值、采样率、检测器���关） |
| `Foundation/CatonMonitorKit/Detectors/CatonDetectable.swift` | Create | 检测器协议 |
| `Foundation/CatonMonitorKit/StackCapture/StackCapture.swift` | Create | thread_get_state + FP 链回溯主线程堆栈 |
| `Foundation/CatonMonitorKit/Detectors/RunLoopDetector.swift` | Create | RunLoop 监控检测器 |
| `Foundation/CatonMonitorKit/Detectors/FPSDetector.swift` | Create | 帧率检测器 |
| `Foundation/CatonMonitorKit/Detectors/WatchdogDetector.swift` | Create | 独立线程死锁检测器 |
| `Foundation/CatonMonitorKit/PageTracker/PageTracker.swift` | Create | swizzle viewDidAppear 维护页面栈 |
| `Foundation/CatonMonitorKit/Storage/CatonStorable.swift` | Create | 存储协议 |
| `Foundation/CatonMonitorKit/Storage/CatonDiskStore.swift` | Create | JSON 文件本地持久化 |
| `Foundation/CatonMonitorKit/Reporter/CatonReportable.swift` | Create | 上报协议 |
| `Foundation/CatonMonitorKit/Reporter/ReportStrategy.swift` | Create | 采样、聚合去重、批量攒发 |
| `Foundation/CatonMonitorKit/DebugUI/CatonOverlayWindow.swift` | Create | Debug 浮窗（FPS + 卡顿闪红） |
| `Foundation/CatonMonitorKit/Core/CatonMonitor.swift` | Create | 协调者，管理管道生命周期 |
| `Podfile` | Modify:27 | 添加 CatonMonitorKit pod 声明 |
| `WeChatSwift/AppDelegate.swift` | Modify:14 | 添加 CatonMonitor.shared.start() |

---

### Task 1: Pod 脚手架 + 数据模型

**Files:**
- Create: `Foundation/CatonMonitorKit/CatonMonitorKit.podspec`
- Create: `Foundation/CatonMonitorKit/Core/CatonEvent.swift`
- Create: `Foundation/CatonMonitorKit/Core/CatonConfig.swift`
- Create: `Foundation/CatonMonitorKit/Detectors/CatonDetectable.swift`

- [ ] **Step 1: 创建 podspec**

```ruby
# Foundation/CatonMonitorKit/CatonMonitorKit.podspec
Pod::Spec.new do |s|
  s.name             = 'CatonMonitorKit'
  s.version          = '1.0.0'
  s.summary          = '企业级卡顿检测框架'
  s.description      = 'RunLoop/FPS/Watchdog 三重检测 + 堆栈采集 + 本地存储 + 上报协议 + Debug 浮窗'
  s.homepage         = 'https://github.com/nicedayzhu/WeChatSwift'
  s.license          = { :type => 'MIT' }
  s.author           = { 'nicedayzhu' => 'nicedayzhu@example.com' }
  s.source           = { :git => '', :tag => s.version.to_s }

  s.ios.deployment_target = '15.1'
  s.swift_version = '5.0'

  s.source_files = '**/*.swift'

  s.frameworks = 'UIKit', 'Foundation', 'QuartzCore'
end
```

- [ ] **Step 2: 创建 CatonEvent.swift**

```swift
// Foundation/CatonMonitorKit/Core/CatonEvent.swift
import Foundation

public enum CatonType: String, Codable {
    case runLoop
    case fps
    case watchdog
}

public struct ThreadInfo: Codable {
    /// 主线程 CPU 时间占比（通过 thread_info THREAD_BASIC_INFO 获取）
    public let cpuUsage: Double
    /// 当前进程线程数
    public let threadCount: Int

    public init(cpuUsage: Double, threadCount: Int) {
        self.cpuUsage = cpuUsage
        self.threadCount = threadCount
    }
}

public struct CatonEvent: Codable {
    public let id: UUID
    public let type: CatonType
    /// 卡顿持续时长（毫秒）
    public let duration: Double
    /// 堆栈帧：Debug 下为符号化字符串，Release 下为原始地址
    public let stackTrace: [String]
    public let timestamp: Date
    public let threadInfo: ThreadInfo
    /// 当前页面类名（通过 PageTracker 获取）
    public let page: String?
    public let isAppInBackground: Bool

    public init(
        type: CatonType,
        duration: Double,
        stackTrace: [String],
        threadInfo: ThreadInfo,
        page: String?,
        isAppInBackground: Bool
    ) {
        self.id = UUID()
        self.type = type
        self.duration = duration
        self.stackTrace = stackTrace
        self.timestamp = Date()
        self.threadInfo = threadInfo
        self.page = page
        self.isAppInBackground = isAppInBackground
    }
}
```

- [ ] **Step 3: 创建 CatonConfig.swift**

```swift
// Foundation/CatonMonitorKit/Core/CatonConfig.swift
import Foundation

public struct CatonConfig {
    // MARK: - 检测器开关
    public var enableRunLoop: Bool
    public var enableFPS: Bool
    public var enableWatchdog: Bool

    // MARK: - 阈值
    /// RunLoop 超过该时长（秒）判定卡顿，默认 100ms
    public var runLoopThreshold: TimeInterval
    /// FPS 连续低于该值触发卡顿事件
    public var fpsDropThreshold: Int
    /// 主线程无响应超过该时长（秒）判定死锁，默认 2s
    public var watchdogTimeout: TimeInterval

    // MARK: - 上报策略
    /// 采样率 0.0~1.0，Release 建议 0.1
    public var sampleRate: Double
    /// 本地最多缓存事件条数
    public var maxStoredEvents: Int
    /// 批量上报触发条数
    public var reportBatchSize: Int

    // MARK: - Debug
    /// 是否显示 Debug 浮窗
    public var showOverlay: Bool

    public init(
        enableRunLoop: Bool = true,
        enableFPS: Bool = true,
        enableWatchdog: Bool = true,
        runLoopThreshold: TimeInterval = 0.1,
        fpsDropThreshold: Int = 10,
        watchdogTimeout: TimeInterval = 2.0,
        sampleRate: Double = 1.0,
        maxStoredEvents: Int = 200,
        reportBatchSize: Int = 20,
        showOverlay: Bool = false
    ) {
        self.enableRunLoop = enableRunLoop
        self.enableFPS = enableFPS
        self.enableWatchdog = enableWatchdog
        self.runLoopThreshold = runLoopThreshold
        self.fpsDropThreshold = fpsDropThreshold
        self.watchdogTimeout = watchdogTimeout
        self.sampleRate = sampleRate
        self.maxStoredEvents = maxStoredEvents
        self.reportBatchSize = reportBatchSize
        self.showOverlay = showOverlay
    }

    public static var `default`: CatonConfig {
        #if DEBUG
        return CatonConfig(showOverlay: true)
        #else
        return CatonConfig(sampleRate: 0.1, showOverlay: false)
        #endif
    }
}
```

- [ ] **Step 4: 创建 CatonDetectable.swift**

```swift
// Foundation/CatonMonitorKit/Detectors/CatonDetectable.swift
import Foundation

public protocol CatonDetectable: AnyObject {
    var onCatonDetected: ((CatonEvent) -> Void)? { get set }
    func start()
    func stop()
}
```

- [ ] **Step 5: 注册 Pod 并验证编译**

在 `Podfile` 的 `# ── Foundation 层 ──` 段落添加：

```ruby
pod 'CatonMonitorKit', :path => 'Foundation/CatonMonitorKit'
```

同时在 `Podfile` 的 `group_map` 中将 `CatonMonitorKit` 加入 Foundation 分组：

```ruby
'Foundation' => %w[ExtensionKit NavigateKit DDNetwork CatonMonitorKit],
```

运行：

```bash
pod install
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add Foundation/CatonMonitorKit/ Podfile Podfile.lock
git commit -m "feat(CatonMonitorKit): pod 脚手架 + 数据模型 + 配置 + 检测器协议"
```

---

### Task 2: StackCapture — 主线程堆栈采集

**Files:**
- Create: `Foundation/CatonMonitorKit/StackCapture/StackCapture.swift`

- [ ] **Step 1: 创建 StackCapture.swift**

```swift
// Foundation/CatonMonitorKit/StackCapture/StackCapture.swift
import Foundation
import MachO

public final class StackCapture {

    /// 最大回溯帧数
    private static let maxFrames = 128

    /// 从子线程采集主线程堆栈
    /// - Returns: 堆栈帧字符串数组（Debug 下符号化，Release 下原始地址）
    public static func captureMainThread() -> [String] {
        guard let mainThread = getMainMachThread() else { return [] }

        var state = arm_thread_state64_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<arm_thread_state64_t>.size / MemoryLayout<natural_t>.size
        )

        let kr = withUnsafeMutablePointer(to: &state) { ptr in
            ptr.withMemoryRebound(to: natural_t.self, capacity: Int(count)) { natPtr in
                thread_get_state(mainThread, ARM_THREAD_STATE64, natPtr, &count)
            }
        }

        guard kr == KERN_SUCCESS else { return [] }

        let addresses = walkFPChain(state: state)
        return symbolicate(addresses)
    }

    // MARK: - 获取主线程 Mach Thread

    private static func getMainMachThread() -> thread_t? {
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0

        let kr = task_threads(mach_task_self_, &threadList, &threadCount)
        guard kr == KERN_SUCCESS, let threads = threadList, threadCount > 0 else {
            return nil
        }

        // 主线程通常是第一个线程
        let mainThread = threads[0]

        // 释放线程列表内存
        let size = vm_size_t(MemoryLayout<thread_t>.size * Int(threadCount))
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), size)

        return mainThread
    }

    // MARK: - FP 链回溯

    private static func walkFPChain(state: arm_thread_state64_t) -> [UnsafeRawPointer] {
        var addresses: [UnsafeRawPointer] = []

        // PC 是当前执行地址
        let pc = UInt(state.__pc)
        if pc != 0 {
            addresses.append(UnsafeRawPointer(bitPattern: pc)!)
        }

        // LR 是返回地址
        let lr = UInt(state.__lr)
        if lr != 0 {
            addresses.append(UnsafeRawPointer(bitPattern: lr)!)
        }

        // 沿 FP 链回溯
        var fp = UInt(state.__fp)
        while fp != 0 && addresses.count < maxFrames {
            let framePtr = UnsafePointer<UInt>(bitPattern: fp)
            guard let frame = framePtr else { break }

            // FP 指向的栈帧结构：[previous_fp, return_address]
            let returnAddress = frame.advanced(by: 1).pointee
            if returnAddress == 0 { break }

            addresses.append(UnsafeRawPointer(bitPattern: returnAddress)!)

            let previousFP = frame.pointee
            // 防止死循环：FP 必须单调递增（栈向低地址增长）
            if previousFP <= fp { break }
            fp = previousFP
        }

        return addresses
    }

    // MARK: - 符号化

    private static func symbolicate(_ addresses: [UnsafeRawPointer]) -> [String] {
        return addresses.enumerated().map { index, addr in
            #if DEBUG
            return debugSymbol(addr, index: index)
            #else
            return releaseSymbol(addr, index: index)
            #endif
        }
    }

    private static func debugSymbol(_ addr: UnsafeRawPointer, index: Int) -> String {
        var info = Dl_info()
        if dladdr(addr, &info) != 0 {
            let symbolName = info.dli_sname.map { String(cString: $0) } ?? "???"
            let offset = addr - UnsafeRawPointer(info.dli_saddr)
            let imageName = info.dli_fname.map {
                String(cString: $0).components(separatedBy: "/").last ?? "???"
            } ?? "???"
            return String(format: "%-4d %-30s 0x%016lx %@ + %d",
                          index, (imageName as NSString).utf8String!, UInt(bitPattern: addr),
                          symbolName, offset)
        }
        return String(format: "%-4d ??? 0x%016lx", index, UInt(bitPattern: addr))
    }

    private static func releaseSymbol(_ addr: UnsafeRawPointer, index: Int) -> String {
        // Release 下只记录地址 + image 信息，服务端用 dSYM 符号化
        var info = Dl_info()
        if dladdr(addr, &info) != 0 {
            let imageName = info.dli_fname.map {
                String(cString: $0).components(separatedBy: "/").last ?? "???"
            } ?? "???"
            let slide = UInt(bitPattern: addr) - UInt(bitPattern: info.dli_fbase)
            return "\(imageName) 0x\(String(slide, radix: 16))"
        }
        return "0x\(String(UInt(bitPattern: addr), radix: 16))"
    }
}
```

- [ ] **Step 2: 验证编译**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

> **注意**：`arm_thread_state64_t` 和 `ARM_THREAD_STATE64` 仅在真机（arm64）和 arm64 模拟器上可用。如果编译报错，需添加 `#if arch(arm64)` 条件编译，x86_64 模拟器 fallback 到 `x86_thread_state64_t`。根据实际编译结果处理。

- [ ] **Step 3: Commit**

```bash
git add Foundation/CatonMonitorKit/StackCapture/
git commit -m "feat(CatonMonitorKit): StackCapture — thread_get_state + FP 链回溯主线程堆栈"
```

---

### Task 3: RunLoopDetector

**Files:**
- Create: `Foundation/CatonMonitorKit/Detectors/RunLoopDetector.swift`

- [ ] **Step 1: 创建 RunLoopDetector.swift**

```swift
// Foundation/CatonMonitorKit/Detectors/RunLoopDetector.swift
import Foundation

public final class RunLoopDetector: CatonDetectable {

    public var onCatonDetected: ((CatonEvent) -> Void)?

    private let threshold: TimeInterval
    private var observer: CFRunLoopObserver?
    private var monitorThread: Thread?
    private let semaphore = DispatchSemaphore(value: 0)

    /// 当前 RunLoop activity，由主线程 Observer 更新
    /// 使用 Int 的原子读写（64 位平台对齐的 Int 读写是原子的）
    private var currentActivity: Int = 0
    private var isRunning = false

    public init(threshold: TimeInterval) {
        self.threshold = threshold
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true

        // 在主线程注册 RunLoop Observer
        let activities: CFRunLoopActivity = [.beforeSources, .afterWaiting, .beforeWaiting]
        observer = CFRunLoopObserverCreateWithHandler(
            kCFAllocatorDefault,
            activities.rawValue,
            true,  // repeats
            0      // order
        ) { [weak self] _, activity in
            guard let self = self else { return }
            self.currentActivity = Int(activity.rawValue)
            self.semaphore.signal()
        }

        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)

        // 启动���控子线程
        let thread = Thread { [weak self] in
            self?.monitorLoop()
        }
        thread.name = "CatonMonitorKit.RunLoopDetector"
        thread.qualityOfService = .userInitiated
        monitorThread = thread
        thread.start()
    }

    public func stop() {
        isRunning = false
        semaphore.signal() // 唤醒等待中的子线程

        if let observer = observer {
            CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, .commonModes)
            self.observer = nil
        }
        monitorThread = nil
    }

    // MARK: - 监控循环

    private func monitorLoop() {
        while isRunning {
            // 等待信号量，超时即可能卡顿
            let result = semaphore.wait(timeout: .now() + threshold)

            if result == .timedOut && isRunning {
                // 只在 beforeSources 和 afterWaiting 阶段超时才算卡顿
                // beforeWaiting = 0x20 (32), beforeSources = 0x04 (4), afterWaiting = 0x40 (64)
                let activity = currentActivity
                let isBeforeSources = (activity & Int(CFRunLoopActivity.beforeSources.rawValue)) != 0
                let isAfterWaiting = (activity & Int(CFRunLoopActivity.afterWaiting.rawValue)) != 0

                if isBeforeSources || isAfterWaiting {
                    let stack = StackCapture.captureMainThread()
                    let threadInfo = ThreadInfoCollector.collect()
                    let event = CatonEvent(
                        type: .runLoop,
                        duration: threshold * 1000,
                        stackTrace: stack,
                        threadInfo: threadInfo,
                        page: nil,   // CatonMonitor 填充
                        isAppInBackground: false
                    )
                    onCatonDetected?(event)
                }
            }
        }
    }
}

// MARK: - ThreadInfoCollector

enum ThreadInfoCollector {
    static func collect() -> ThreadInfo {
        var threadInfo = thread_basic_info_data_t()
        var count = mach_msg_type_number_t(THREAD_BASIC_INFO_COUNT)
        var mainThread: thread_t = 0

        // 获取主线程
        var threadList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        if task_threads(mach_task_self_, &threadList, &threadCount) == KERN_SUCCESS,
           let threads = threadList, threadCount > 0 {
            mainThread = threads[0]
            let size = vm_size_t(MemoryLayout<thread_t>.size * Int(threadCount))
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), size)
        }

        var cpuUsage: Double = 0
        if mainThread != 0 {
            let kr = withUnsafeMutablePointer(to: &threadInfo) { ptr in
                ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                    thread_info(mainThread, thread_flavor_t(THREAD_BASIC_INFO), intPtr, &count)
                }
            }
            if kr == KERN_SUCCESS {
                cpuUsage = Double(threadInfo.cpu_usage) / Double(TH_USAGE_SCALE) * 100
            }
        }

        // 进程线程数
        var taskInfo = mach_task_basic_info_data_t()
        var taskInfoCount = mach_msg_type_number_t(MACH_TASK_BASIC_INFO_COUNT)
        var threadTotal = 0
        let taskKr = withUnsafeMutablePointer(to: &taskInfo) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(taskInfoCount)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), intPtr, &taskInfoCount)
            }
        }
        if taskKr == KERN_SUCCESS {
            // 用 task_threads 获取更准确的线程数
            var tList: thread_act_array_t?
            var tCount: mach_msg_type_number_t = 0
            if task_threads(mach_task_self_, &tList, &tCount) == KERN_SUCCESS {
                threadTotal = Int(tCount)
                if let list = tList {
                    vm_deallocate(mach_task_self_, vm_address_t(bitPattern: list),
                                  vm_size_t(MemoryLayout<thread_t>.size * Int(tCount)))
                }
            }
        }

        return ThreadInfo(cpuUsage: cpuUsage, threadCount: threadTotal)
    }
}
```

- [ ] **Step 2: 验证编译**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Foundation/CatonMonitorKit/Detectors/RunLoopDetector.swift
git commit -m "feat(CatonMonitorKit): RunLoopDetector — 信号量 + RunLoop Observer 卡顿检测"
```

---

### Task 4: FPSDetector

**Files:**
- Create: `Foundation/CatonMonitorKit/Detectors/FPSDetector.swift`

- [ ] **Step 1: 创建 FPSDetector.swift**

```swift
// Foundation/CatonMonitorKit/Detectors/FPSDetector.swift
import UIKit
import QuartzCore

public final class FPSDetector: CatonDetectable {

    public var onCatonDetected: ((CatonEvent) -> Void)?
    /// 实时 FPS 值回调（给浮窗用）
    public var onFPSUpdate: ((Int) -> Void)?

    private let dropThreshold: Int
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0
    /// 连续低帧计数（连续 3 秒低于阈值才触发事件）
    private var consecutiveLowCount: Int = 0
    private static let triggerSeconds = 3

    public init(dropThreshold: Int) {
        self.dropThreshold = dropThreshold
    }

    public func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
        lastTimestamp = 0
        frameCount = 0
        consecutiveLowCount = 0
    }

    public func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func tick(_ link: CADisplayLink) {
        if lastTimestamp == 0 {
            lastTimestamp = link.timestamp
            return
        }

        frameCount += 1
        let elapsed = link.timestamp - lastTimestamp

        // 每秒计算一次 FPS
        if elapsed >= 1.0 {
            let fps = Int(round(Double(frameCount) / elapsed))
            frameCount = 0
            lastTimestamp = link.timestamp

            onFPSUpdate?(fps)

            if fps < dropThreshold {
                consecutiveLowCount += 1
            } else {
                consecutiveLowCount = 0
            }

            // 连续低帧达到阈值才触发
            if consecutiveLowCount >= FPSDetector.triggerSeconds {
                let stack = StackCapture.captureMainThread()
                let threadInfo = ThreadInfoCollector.collect()
                let event = CatonEvent(
                    type: .fps,
                    duration: Double(consecutiveLowCount) * 1000,
                    stackTrace: stack,
                    threadInfo: threadInfo,
                    page: nil,
                    isAppInBackground: false
                )
                onCatonDetected?(event)
                consecutiveLowCount = 0  // 重置，避免持续触发
            }
        }
    }

    deinit {
        stop()
    }
}
```

- [ ] **Step 2: 验证编译**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Foundation/CatonMonitorKit/Detectors/FPSDetector.swift
git commit -m "feat(CatonMonitorKit): FPSDetector — CADisplayLink 帧率检测"
```

---

### Task 5: WatchdogDetector

**Files:**
- Create: `Foundation/CatonMonitorKit/Detectors/WatchdogDetector.swift`

- [ ] **Step 1: 创建 WatchdogDetector.swift**

```swift
// Foundation/CatonMonitorKit/Detectors/WatchdogDetector.swift
import Foundation

public final class WatchdogDetector: CatonDetectable {

    public var onCatonDetected: ((CatonEvent) -> Void)?

    private let timeout: TimeInterval
    private var watchdogThread: Thread?
    private var timer: CFRunLoopTimer?
    private var isRunning = false

    /// 主线程最近一次 pong 的时间戳（Mach absolute time）
    /// 由主线程 RunLoop timer 更新，子线程读取
    private var lastPongTime: UInt64 = 0

    public init(timeout: TimeInterval) {
        self.timeout = timeout
    }

    public func start() {
        guard !isRunning else { return }
        isRunning = true
        lastPongTime = mach_absolute_time()

        // 在主线程 RunLoop 注册 Timer（commonModes，滚动时也能触发）
        // 更新频率 = timeout / 4，确保在超时窗口内有足够的更新机会
        let interval = timeout / 4.0
        let timer = CFRunLoopTimerCreateWithHandler(
            kCFAllocatorDefault,
            CFAbsoluteTimeGetCurrent() + interval,
            interval,
            0, 0
        ) { [weak self] _ in
            self?.lastPongTime = mach_absolute_time()
        }
        CFRunLoopAddTimer(CFRunLoopGetMain(), timer, .commonModes)
        self.timer = timer

        // 启动 watchdog 子线程
        let thread = Thread { [weak self] in
            self?.watchdogLoop()
        }
        thread.name = "CatonMonitorKit.WatchdogDetector"
        thread.qualityOfService = .userInteractive
        watchdogThread = thread
        thread.start()
    }

    public func stop() {
        isRunning = false

        if let timer = timer {
            CFRunLoopTimerInvalidate(timer)
            self.timer = nil
        }
        watchdogThread = nil
    }

    // MARK: - Watchdog 循环

    private func watchdogLoop() {
        // 获取 Mach timebase 用于转换为秒
        var timebaseInfo = mach_timebase_info_data_t()
        mach_timebase_info(&timebaseInfo)
        let nanoPerTick = Double(timebaseInfo.numer) / Double(timebaseInfo.denom)

        while isRunning {
            Thread.sleep(forTimeInterval: timeout)
            guard isRunning else { break }

            let now = mach_absolute_time()
            let lastPong = lastPongTime
            let elapsedNanos = Double(now - lastPong) * nanoPerTick
            let elapsedSeconds = elapsedNanos / 1_000_000_000

            if elapsedSeconds >= timeout {
                let stack = StackCapture.captureMainThread()
                let threadInfo = ThreadInfoCollector.collect()
                let event = CatonEvent(
                    type: .watchdog,
                    duration: elapsedSeconds * 1000,
                    stackTrace: stack,
                    threadInfo: threadInfo,
                    page: nil,
                    isAppInBackground: false
                )
                onCatonDetected?(event)
            }
        }
    }

    deinit {
        stop()
    }
}
```

- [ ] **Step 2: 验证编译**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Foundation/CatonMonitorKit/Detectors/WatchdogDetector.swift
git commit -m "feat(CatonMonitorKit): WatchdogDetector — CFRunLoopTimer + 时间戳死锁检测"
```

---

### Task 6: PageTracker — 页面栈追踪

**Files:**
- Create: `Foundation/CatonMonitorKit/PageTracker/PageTracker.swift`

- [ ] **Step 1: 创建 PageTracker.swift**

```swift
// Foundation/CatonMonitorKit/PageTracker/PageTracker.swift
import UIKit

public final class PageTracker {

    public static let shared = PageTracker()

    private var currentPageName: String?
    private let lock = NSLock()
    private var swizzled = false

    private init() {}

    /// 获取当前页面类名
    public var currentPage: String? {
        lock.lock()
        defer { lock.unlock() }
        return currentPageName
    }

    /// 启动 swizzle，自动追踪页面切换
    public func start() {
        guard !swizzled else { return }
        swizzled = true
        swizzleViewDidAppear()
    }

    /// 手动设置当前页面（优先级高于自动追踪）
    public func setCurrentPage(_ name: String) {
        lock.lock()
        currentPageName = name
        lock.unlock()
    }

    // MARK: - Swizzle

    private func swizzleViewDidAppear() {
        let originalSelector = #selector(UIViewController.viewDidAppear(_:))
        let swizzledSelector = #selector(UIViewController.caton_viewDidAppear(_:))

        guard let originalMethod = class_getInstanceMethod(UIViewController.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzledSelector)
        else { return }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}

// MARK: - UIViewController Swizzle

extension UIViewController {

    @objc func caton_viewDidAppear(_ animated: Bool) {
        // 调用原始实现（已交换，所以调 caton_ 就是调原始）
        caton_viewDidAppear(animated)

        // 过滤系统容器 VC，只记录内容页面
        let isContainer = self is UINavigationController
            || self is UITabBarController
            || self is UISplitViewController

        if !isContainer {
            let pageName = String(describing: type(of: self))
            PageTracker.shared.setCurrentPage(pageName)
        }
    }
}
```

- [ ] **Step 2: 验证编译**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Foundation/CatonMonitorKit/PageTracker/
git commit -m "feat(CatonMonitorKit): PageTracker — swizzle viewDidAppear 自动追踪页面栈"
```

---

### Task 7: CatonDiskStore — 本地持久化

**Files:**
- Create: `Foundation/CatonMonitorKit/Storage/CatonStorable.swift`
- Create: `Foundation/CatonMonitorKit/Storage/CatonDiskStore.swift`

- [ ] **Step 1: 创建 CatonStorable.swift**

```swift
// Foundation/CatonMonitorKit/Storage/CatonStorable.swift
import Foundation

public protocol CatonStorable {
    func save(_ event: CatonEvent)
    func loadAll() -> [CatonEvent]
    func remove(ids: [UUID])
    func clear()
}
```

- [ ] **Step 2: 创建 CatonDiskStore.swift**

```swift
// Foundation/CatonMonitorKit/Storage/CatonDiskStore.swift
import Foundation

public final class CatonDiskStore: CatonStorable {

    private let directory: URL
    private let queue = DispatchQueue(label: "CatonMonitorKit.DiskStore")
    private let maxEvents: Int
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(maxEvents: Int = 200) {
        self.maxEvents = maxEvents
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        directory = caches.appendingPathComponent("CatonMonitorKit", isDirectory: true)

        // 确保目录存在
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    public func save(_ event: CatonEvent) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let fileURL = self.directory.appendingPathComponent("\(event.id.uuidString).json")
            if let data = try? self.encoder.encode(event) {
                try? data.write(to: fileURL, options: .atomic)
            }
            self.trimIfNeeded()
        }
    }

    public func loadAll() -> [CatonEvent] {
        return queue.sync {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            ) else { return [] }

            return files
                .filter { $0.pathExtension == "json" }
                .compactMap { url -> CatonEvent? in
                    guard let data = try? Data(contentsOf: url) else { return nil }
                    return try? decoder.decode(CatonEvent.self, from: data)
                }
                .sorted { $0.timestamp < $1.timestamp }
        }
    }

    public func remove(ids: [UUID]) {
        queue.async { [weak self] in
            guard let self = self else { return }
            for id in ids {
                let fileURL = self.directory.appendingPathComponent("\(id.uuidString).json")
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
    }

    public func clear() {
        queue.async { [weak self] in
            guard let self = self else { return }
            if let files = try? FileManager.default.contentsOfDirectory(
                at: self.directory, includingPropertiesForKeys: nil
            ) {
                for file in files {
                    try? FileManager.default.removeItem(at: file)
                }
            }
        }
    }

    // MARK: - 清理

    private func trimIfNeeded() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: [.creationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        let jsonFiles = files.filter { $0.pathExtension == "json" }
        if jsonFiles.count > maxEvents {
            // 按创建时间排序，删除最旧的
            let sorted = jsonFiles.sorted { a, b in
                let dateA = (try? a.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                let dateB = (try? b.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
                return dateA < dateB
            }
            let toDelete = sorted.prefix(jsonFiles.count - maxEvents)
            for file in toDelete {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
```

- [ ] **Step 3: 验证编译**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Foundation/CatonMonitorKit/Storage/
git commit -m "feat(CatonMonitorKit): CatonDiskStore — JSON 文件本地持久化"
```

---

### Task 8: Reporter 协议 + ReportStrategy

**Files:**
- Create: `Foundation/CatonMonitorKit/Reporter/CatonReportable.swift`
- Create: `Foundation/CatonMonitorKit/Reporter/ReportStrategy.swift`

- [ ] **Step 1: 创建 CatonReportable.swift**

```swift
// Foundation/CatonMonitorKit/Reporter/CatonReportable.swift
import Foundation

public protocol CatonReportable {
    func report(events: [CatonEvent], completion: @escaping (Bool) -> Void)
}
```

- [ ] **Step 2: 创建 ReportStrategy.swift**

```swift
// Foundation/CatonMonitorKit/Reporter/ReportStrategy.swift
import UIKit

public final class ReportStrategy {

    private let config: CatonConfig
    private let store: CatonStorable
    private weak var reporter: (any CatonReportable)?

    private var pendingQueue: [CatonEvent] = []
    private let lock = NSLock()
    private var lastReportTime: Date = .distantPast
    private var backgroundObserver: NSObjectProtocol?
    private var reportTimer: Timer?

    /// 设备采样种子（对 identifierForVendor hash 取模，保证同设备一致）
    private let shouldSample: Bool

    public init(config: CatonConfig, store: CatonStorable) {
        self.config = config
        self.store = store

        // 设备维度采样：同一设备始终采或始终不采
        let vendorID = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        let hash = vendorID.hashValue
        let bucket = abs(hash) % 100
        shouldSample = bucket < Int(config.sampleRate * 100)
    }

    public func setReporter(_ reporter: CatonReportable?) {
        self.reporter = reporter
    }

    /// 启动上报策略（定时检查 + 后台触发）
    public func start() {
        // 定时检查（每 5 分钟）
        reportTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.flushIfNeeded()
        }

        // App 进入后台时触发上报
        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.flush()
        }
    }

    public func stop() {
        reportTimer?.invalidate()
        reportTimer = nil
        if let observer = backgroundObserver {
            NotificationCenter.default.removeObserver(observer)
            backgroundObserver = nil
        }
    }

    /// 入队事件
    public func enqueue(_ event: CatonEvent) {
        // 采样过滤
        guard shouldSample else { return }

        lock.lock()
        // 聚合去重：同一页面 + 同一堆栈 top 3 帧视为同类
        let isDuplicate = pendingQueue.contains { existing in
            existing.page == event.page && isSameStack(existing.stackTrace, event.stackTrace)
        }
        if !isDuplicate {
            pendingQueue.append(event)
        }
        let count = pendingQueue.count
        lock.unlock()

        // 批量触发
        if count >= config.reportBatchSize {
            flush()
        }
    }

    /// 加载历史未上报事件
    public func loadPendingFromDisk() {
        let events = store.loadAll()
        guard !events.isEmpty else { return }

        lock.lock()
        pendingQueue.append(contentsOf: events)
        lock.unlock()
    }

    // MARK: - Private

    private func flushIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastReportTime) >= 300 else { return }
        flush()
    }

    private func flush() {
        lock.lock()
        guard !pendingQueue.isEmpty else {
            lock.unlock()
            return
        }
        let batch = Array(pendingQueue.prefix(config.reportBatchSize))
        lock.unlock()

        reporter?.report(events: batch) { [weak self] success in
            guard let self = self, success else { return }

            self.lock.lock()
            let reportedIDs = Set(batch.map { $0.id })
            self.pendingQueue.removeAll { reportedIDs.contains($0.id) }
            self.lock.unlock()

            // 从磁盘删除已上报的
            self.store.remove(ids: Array(reportedIDs))
            self.lastReportTime = Date()
        }
    }

    private func isSameStack(_ a: [String], _ b: [String]) -> Bool {
        let topA = a.prefix(3)
        let topB = b.prefix(3)
        guard topA.count == topB.count else { return false }
        return zip(topA, topB).allSatisfy { $0 == $1 }
    }

    deinit {
        stop()
    }
}
```

- [ ] **Step 3: 验证编译**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add Foundation/CatonMonitorKit/Reporter/
git commit -m "feat(CatonMonitorKit): CatonReportable + ReportStrategy — 采样/聚合/批量上报"
```

---

### Task 9: CatonOverlayWindow — Debug 浮窗

**Files:**
- Create: `Foundation/CatonMonitorKit/DebugUI/CatonOverlayWindow.swift`

- [ ] **Step 1: 创建 CatonOverlayWindow.swift**

```swift
// Foundation/CatonMonitorKit/DebugUI/CatonOverlayWindow.swift

#if DEBUG
import UIKit

public final class CatonOverlayWindow: UIWindow {

    private let fpsLabel = UILabel()
    private let catonLabel = UILabel()
    private let containerView = UIView()
    private var catonCount: Int = 0
    private var recentEvents: [CatonEvent] = []
    private var detailExpanded = false
    private let detailStackView = UIStackView()

    public override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setup() {
        windowLevel = .statusBar + 1
        isHidden = false
        isUserInteractionEnabled = true
        backgroundColor = .clear

        let width: CGFloat = 80
        let height: CGFloat = 44
        let topPadding = windowScene?.statusBarManager?.statusBarFrame.height ?? 44
        frame = CGRect(x: UIScreen.main.bounds.width - width - 8,
                       y: topPadding + 4,
                       width: width, height: height)

        containerView.frame = bounds
        containerView.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        containerView.layer.cornerRadius = 6
        containerView.clipsToBounds = true
        addSubview(containerView)

        // FPS 标签
        fpsLabel.frame = CGRect(x: 4, y: 2, width: width - 8, height: 18)
        fpsLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        fpsLabel.textColor = .green
        fpsLabel.text = "FPS: --"
        containerView.addSubview(fpsLabel)

        // 卡顿次数标签
        catonLabel.frame = CGRect(x: 4, y: 22, width: width - 8, height: 18)
        catonLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        catonLabel.textColor = .white
        catonLabel.text = "Caton: 0"
        containerView.addSubview(catonLabel)

        // 详情区域（默认隐藏）
        detailStackView.axis = .vertical
        detailStackView.spacing = 2
        detailStackView.isHidden = true
        containerView.addSubview(detailStackView)

        // 手势
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        containerView.addGestureRecognizer(pan)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        containerView.addGestureRecognizer(tap)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        containerView.addGestureRecognizer(longPress)
    }

    // MARK: - Public Updates

    public func updateFPS(_ fps: Int) {
        fpsLabel.text = "FPS: \(fps)"
        if fps >= 45 {
            fpsLabel.textColor = .green
        } else if fps >= 30 {
            fpsLabel.textColor = .yellow
        } else {
            fpsLabel.textColor = .red
        }
    }

    public func recordCaton(_ event: CatonEvent) {
        catonCount += 1
        catonLabel.text = "Caton: \(catonCount)"

        recentEvents.append(event)
        if recentEvents.count > 5 {
            recentEvents.removeFirst()
        }

        // 闪红
        flashRed()
        updateDetailIfExpanded()
    }

    // MARK: - Flash

    private func flashRed() {
        let original = containerView.backgroundColor
        UIView.animate(withDuration: 0.15, animations: {
            self.containerView.backgroundColor = UIColor.red.withAlphaComponent(0.8)
        }) { _ in
            UIView.animate(withDuration: 0.15) {
                self.containerView.backgroundColor = original
            }
        }
    }

    // MARK: - Gestures

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: superview)
        center = CGPoint(x: center.x + translation.x, y: center.y + translation.y)
        gesture.setTranslation(.zero, in: superview)
    }

    @objc private func handleTap() {
        detailExpanded.toggle()
        if detailExpanded {
            expandDetail()
        } else {
            collapseDetail()
        }
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        // 复制最近一条卡顿堆栈到剪贴板
        if let lastEvent = recentEvents.last {
            let stackString = lastEvent.stackTrace.joined(separator: "\n")
            UIPasteboard.general.string = "[\(lastEvent.type.rawValue)] \(lastEvent.page ?? "?")\n\(stackString)"

            // 短暂变蓝提示已复制
            let original = containerView.backgroundColor
            containerView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.containerView.backgroundColor = original
            }
        }
    }

    // MARK: - Detail Panel

    private func expandDetail() {
        detailStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for event in recentEvents.suffix(5) {
            let label = UILabel()
            label.font = UIFont.monospacedSystemFont(ofSize: 9, weight: .regular)
            label.textColor = .white
            let page = event.page ?? "Unknown"
            label.text = "  \(page) \(Int(event.duration))ms"
            detailStackView.addArrangedSubview(label)
        }

        let detailHeight = CGFloat(min(recentEvents.count, 5)) * 14
        let newHeight: CGFloat = 44 + detailHeight + 4
        detailStackView.frame = CGRect(x: 4, y: 44, width: bounds.width - 8, height: detailHeight)
        detailStackView.isHidden = false

        frame.size.height = newHeight
        containerView.frame = bounds
    }

    private func collapseDetail() {
        detailStackView.isHidden = true
        frame.size.height = 44
        containerView.frame = bounds
    }

    private func updateDetailIfExpanded() {
        guard detailExpanded else { return }
        expandDetail()
    }

    // MARK: - 不拦截非浮窗区域的触摸

    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        return view == self ? nil : view
    }
}
#endif
```

- [ ] **Step 2: 验证编译**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Foundation/CatonMonitorKit/DebugUI/
git commit -m "feat(CatonMonitorKit): CatonOverlayWindow — Debug 浮窗（FPS + 卡顿闪红 + 详情面板）"
```

---

### Task 10: CatonMonitor — 协调者

**Files:**
- Create: `Foundation/CatonMonitorKit/Core/CatonMonitor.swift`

- [ ] **Step 1: 创建 CatonMonitor.swift**

```swift
// Foundation/CatonMonitorKit/Core/CatonMonitor.swift
import UIKit

public final class CatonMonitor {

    public static let shared = CatonMonitor()

    /// 业务方注入上报实现
    public var reporter: CatonReportable? {
        didSet {
            reportStrategy?.setReporter(reporter)
        }
    }

    private var config: CatonConfig?
    private var detectors: [CatonDetectable] = []
    private var fpsDetector: FPSDetector?
    private var store: CatonDiskStore?
    private var reportStrategy: ReportStrategy?
    private var isRunning = false

    #if DEBUG
    private var overlayWindow: CatonOverlayWindow?
    #endif

    private init() {}

    // MARK: - Public API

    public func start(config: CatonConfig = .default) {
        guard !isRunning else { return }
        isRunning = true
        self.config = config

        // 启动页面追踪
        PageTracker.shared.start()

        // 初始化存储
        let diskStore = CatonDiskStore(maxEvents: config.maxStoredEvents)
        self.store = diskStore

        // 初始化上报策略
        let strategy = ReportStrategy(config: config, store: diskStore)
        strategy.setReporter(reporter)
        strategy.start()
        self.reportStrategy = strategy

        // 创建并启动检测器
        if config.enableRunLoop {
            let detector = RunLoopDetector(threshold: config.runLoopThreshold)
            detector.onCatonDetected = { [weak self] event in
                self?.handleEvent(event)
            }
            detector.start()
            detectors.append(detector)
        }

        if config.enableFPS {
            let detector = FPSDetector(dropThreshold: config.fpsDropThreshold)
            detector.onCatonDetected = { [weak self] event in
                self?.handleEvent(event)
            }
            detector.onFPSUpdate = { [weak self] fps in
                #if DEBUG
                DispatchQueue.main.async {
                    self?.overlayWindow?.updateFPS(fps)
                }
                #endif
            }
            detector.start()
            detectors.append(detector)
            fpsDetector = detector
        }

        if config.enableWatchdog {
            let detector = WatchdogDetector(timeout: config.watchdogTimeout)
            detector.onCatonDetected = { [weak self] event in
                self?.handleEvent(event)
            }
            detector.start()
            detectors.append(detector)
        }

        // Debug 浮窗
        #if DEBUG
        if config.showOverlay {
            DispatchQueue.main.async { [weak self] in
                guard let scene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first else { return }
                let overlay = CatonOverlayWindow(windowScene: scene)
                self?.overlayWindow = overlay
            }
        }
        #endif

        // 延迟加载历史未上报事件
        DispatchQueue.global().asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.reportStrategy?.loadPendingFromDisk()
        }

        printStartupLog(config: config)
    }

    public func stop() {
        guard isRunning else { return }
        isRunning = false

        detectors.forEach { $0.stop() }
        detectors.removeAll()
        fpsDetector = nil

        reportStrategy?.stop()
        reportStrategy = nil

        #if DEBUG
        DispatchQueue.main.async { [weak self] in
            self?.overlayWindow?.isHidden = true
            self?.overlayWindow = nil
        }
        #endif
    }

    /// 临时暂停检测（已知耗时操作时调用）
    public func pauseDetection() {
        detectors.forEach { $0.stop() }
    }

    /// 恢复检测
    public func resumeDetection() {
        detectors.forEach { $0.start() }
    }

    // MARK: - 事件管道

    private func handleEvent(_ event: CatonEvent) {
        // 填充页面信息
        let page = PageTracker.shared.currentPage
        let isBackground = UIApplication.shared.applicationState == .background

        let enrichedEvent = CatonEvent(
            type: event.type,
            duration: event.duration,
            stackTrace: event.stackTrace,
            threadInfo: event.threadInfo,
            page: page,
            isAppInBackground: isBackground
        )

        // 后台状态不记录（可能误报）
        guard !enrichedEvent.isAppInBackground else { return }

        // 存储
        store?.save(enrichedEvent)

        // 入队上报
        reportStrategy?.enqueue(enrichedEvent)

        // Debug 输出
        #if DEBUG
        printCatonLog(enrichedEvent)
        DispatchQueue.main.async { [weak self] in
            self?.overlayWindow?.recordCaton(enrichedEvent)
        }
        #endif

        // 广播通知
        NotificationCenter.default.post(
            name: CatonMonitor.catonDetectedNotification,
            object: enrichedEvent
        )
    }

    // MARK: - Notification

    public static let catonDetectedNotification = Notification.Name("CatonMonitorKit.catonDetected")

    // MARK: - Logging

    private func printStartupLog(config: CatonConfig) {
        #if DEBUG
        let detectorList = [
            config.enableRunLoop ? "RunLoop(\(Int(config.runLoopThreshold * 1000))ms)" : nil,
            config.enableFPS ? "FPS(<\(config.fpsDropThreshold))" : nil,
            config.enableWatchdog ? "Watchdog(\(Int(config.watchdogTimeout))s)" : nil,
        ].compactMap { $0 }.joined(separator: " + ")

        print("┌──────────────────────────────────────")
        print("│ 🔍 CatonMonitorKit Started")
        print("│ Detectors: \(detectorList)")
        print("│ Overlay: \(config.showOverlay)")
        print("│ SampleRate: \(config.sampleRate)")
        print("└──────────────────────────────────────")
        #endif
    }

    private func printCatonLog(_ event: CatonEvent) {
        #if DEBUG
        print("⚠️ [CatonMonitorKit] \(event.type.rawValue) detected")
        print("   Page: \(event.page ?? "Unknown") | Duration: \(Int(event.duration))ms")
        print("   CPU: \(String(format: "%.1f%%", event.threadInfo.cpuUsage)) | Threads: \(event.threadInfo.threadCount)")
        if !event.stackTrace.isEmpty {
            print("   Stack (top 5):")
            for frame in event.stackTrace.prefix(5) {
                print("     \(frame)")
            }
        }
        #endif
    }
}
```

- [ ] **Step 2: 验证编译**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Foundation/CatonMonitorKit/Core/CatonMonitor.swift
git commit -m "feat(CatonMonitorKit): CatonMonitor — 协调者，管理检测管道生命周期"
```

---

### Task 11: 接入主工程

**Files:**
- Modify: `Podfile:27`
- Modify: `WeChatSwift/AppDelegate.swift:1`

- [ ] **Step 1: 在 Podfile 添加 pod 声明**

（如果 Task 1 Step 5 已完成则跳过此步）

在 `Podfile` 的 `# ── Foundation 层 ──` 下添加：

```ruby
pod 'CatonMonitorKit', :path => 'Foundation/CatonMonitorKit'
```

在 `group_map` 中：

```ruby
'Foundation' => %w[ExtensionKit NavigateKit DDNetwork CatonMonitorKit],
```

- [ ] **Step 2: 在 AppDelegate 启动 CatonMonitor**

在 `WeChatSwift/AppDelegate.swift` 的 import 区域添加：

```swift
import CatonMonitorKit
```

在 `didFinishLaunchingWithOptions` 方法中，`LaunchMetrics.mark("didFinishStart")` 之后添加：

```swift
// ── 卡顿检测 ──
CatonMonitor.shared.start()
```

完整 AppDelegate 修改后：

```swift
import UIKit
import WeChatRN
import ChatModule
import ContactModule
import DiscoverModule
import MeModule
import CatonMonitorKit

class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        LaunchMetrics.mark("didFinishStart")

        // ── 卡顿检测 ──
        CatonMonitor.shared.start()

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

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
    }
}
```

- [ ] **Step 3: pod install + 完整编译验证**

```bash
pod install
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: 运行模拟器验证**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 16 Pro' -quiet && xcrun simctl boot "iPhone 16 Pro" 2>/dev/null; xcrun simctl install "iPhone 16 Pro" build/Build/Products/Debug-iphonesimulator/WeChatSwift.app && xcrun simctl launch --console-stdout "iPhone 16 Pro" com.study.wcSwift 2>&1 | head -30
```

Expected:
- 控制台输出 `CatonMonitorKit Started` 启动日志
- 浮窗显示 FPS 数值（Debug 模式）

- [ ] **Step 5: Commit**

```bash
git add Podfile Podfile.lock WeChatSwift/AppDelegate.swift
git commit -m "feat: 接入 CatonMonitorKit 到主工程，AppDelegate 启动卡顿检测"
```
