import Foundation
import UIKit
import Network

/// 自动触发 Sync 的兜底机制 — 全部 force=false,Mock 服务不打扰演示,
/// 真服务端实现里这些路径会拉真实增量。
public final class SyncTriggers {
    private let coordinator: SyncCoordinator
    private var pathMonitor: NWPathMonitor?
    private var pollTimer: Timer?
    private var foregroundObserver: NSObjectProtocol?
    private var hasFiredFirstNetwork = false

    public init(coordinator: SyncCoordinator) {
        self.coordinator = coordinator
    }

    public func start() {
        // 1. 前台
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.fire(reason: "foreground")
        }

        // 2. 网络恢复
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            // 第一次 satisfied 是启动时的初始状态,不算"恢复",跳过
            if path.status == .satisfied {
                if !self.hasFiredFirstNetwork {
                    self.hasFiredFirstNetwork = true
                    return
                }
                self.fire(reason: "network-recovered")
            }
        }
        monitor.start(queue: DispatchQueue(label: "im.sync.netpath"))
        pathMonitor = monitor

        // 3. 90s 定时兜底
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pollTimer?.invalidate()
            self.pollTimer = Timer.scheduledTimer(withTimeInterval: 90, repeats: true) { [weak self] _ in
                self?.fire(reason: "polling")
            }
        }
    }

    public func stop() {
        if let obs = foregroundObserver {
            NotificationCenter.default.removeObserver(obs)
            foregroundObserver = nil
        }
        pathMonitor?.cancel()
        pathMonitor = nil
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func fire(reason: String) {
        print("[SyncTrigger] 🔔 \(reason) → triggerSync(force:false)")
        Task { await coordinator.triggerSync(force: false) }
    }
}
