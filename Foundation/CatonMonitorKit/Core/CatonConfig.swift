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
        let debugging = CatonConfig.isDebuggerAttached
        #if DEBUG
        return CatonConfig(showOverlay: true)
        #else
        return CatonConfig(sampleRate: debugging ? 1.0 : 0.1,
                           showOverlay: debugging)
        #endif
    }

    /// 运行时检测调试器是否附着（sysctl P_TRACED）
    /// Xcode 调试时为 true，脱离 Xcode 独立运行为 false
    private static var isDebuggerAttached: Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        let result = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        guard result == 0 else { return false }
        return (info.kp_proc.p_flag & P_TRACED) != 0
    }
}
