import UIKit

public final class ReportStrategy {

    private let config: CatonConfig
    private let store: CatonStorable
    private var reporter: (any CatonReportable)?

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
        reportTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.flushIfNeeded()
        }

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
        guard shouldSample else { return }

        lock.lock()
        let isDuplicate = pendingQueue.contains { existing in
            existing.page == event.page && isSameStack(existing.stackTrace, event.stackTrace)
        }
        if !isDuplicate {
            pendingQueue.append(event)
        }
        let count = pendingQueue.count
        lock.unlock()

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
