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
