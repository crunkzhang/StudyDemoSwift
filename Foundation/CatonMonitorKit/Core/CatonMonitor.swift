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

    private var overlayWindow: CatonOverlayWindow?

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
                DispatchQueue.main.async {
                    self?.overlayWindow?.updateFPS(fps)
                }
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

        // 浮窗（由 config.showOverlay 运行时控制）
        if config.showOverlay {
            DispatchQueue.main.async { [weak self] in
                guard let scene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first else { return }
                let overlay = CatonOverlayWindow(windowScene: scene)
                self?.overlayWindow = overlay
            }
        }

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

        DispatchQueue.main.async { [weak self] in
            self?.overlayWindow?.isHidden = true
            self?.overlayWindow = nil
        }
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
        let page = PageTracker.shared.currentPage

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let isBackground = UIApplication.shared.applicationState == .background

            let enrichedEvent = CatonEvent(
                type: event.type,
                duration: event.duration,
                stackTrace: event.stackTrace,
                threadInfo: event.threadInfo,
                page: page,
                isAppInBackground: isBackground
            )

            // 后台状态不记录
            guard !enrichedEvent.isAppInBackground else { return }

            self.store?.save(enrichedEvent)
            self.reportStrategy?.enqueue(enrichedEvent)

            #if DEBUG
            self.printCatonLog(enrichedEvent)
            #endif

            self.overlayWindow?.recordCaton(enrichedEvent)

            NotificationCenter.default.post(
                name: CatonMonitor.catonDetectedNotification,
                object: enrichedEvent
            )
        }
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
