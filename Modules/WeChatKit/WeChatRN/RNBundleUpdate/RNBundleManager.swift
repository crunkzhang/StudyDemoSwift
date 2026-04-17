import Foundation

public final class RNBundleManager {
    public static let shared = RNBundleManager()

    private var remoteURL: String = ""
    private var appVersion: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"

    private let store = BundleFileStorage()
    private let fetcher = BundleConfigFetcher()
    private let resolver = BundleVersionResolver()
    private lazy var downloader = BundleDownloader(store: store)

    var reporter: BundleEventReporter = ConsoleBundleReporter()

    private var isChecking = false
    private var pollTimer: Timer?
    private var pollInterval: TimeInterval = 30 * 60

    private init() {}
}

// MARK: - Public

public extension RNBundleManager {
    var bundlePath: URL? {
        store.currentBundlePath
    }

    func configure(remoteURL: String, appVersion: String) {
        self.remoteURL = remoteURL
        self.appVersion = appVersion
    }

    func start() {
        checkRollback()
        registerHealthObserver()
        checkUpdate()
        startPolling()
    }

    func checkUpdate() {
        guard !remoteURL.isEmpty else { return }
        guard !isChecking else { return }

        let now = Date().timeIntervalSince1970
        guard now - store.state.lastCheckTime >= 60 else { return }

        isChecking = true
        store.updateCheckTime()

        reporter.report(BundleEvent(.checkUpdate, [
            "deviceId": store.state.deviceId,
            "currentVersion": store.state.currentVersion,
            "appVersion": appVersion
        ]))

        fetcher.fetch(remoteURL: remoteURL) { [weak self] result in
            guard let self else { return }
            defer { self.isChecking = false }

            switch result {
            case .success(let config):
                self.handleConfig(config)
            case .failure(let error):
                self.reporter.report(BundleEvent(.configFetchFail, [
                    "errorMsg": "\(error)"
                ]))
            }
        }
    }

    func markHealthy() {
        store.markHealthy()
        reporter.report(BundleEvent(.loadSuccess, [
            "deviceId": store.state.deviceId,
            "version": store.state.currentVersion,
            "source": !store.state.currentVersion.isEmpty ? "downloaded" : "builtin"
        ]))
    }
}

// MARK: - Private

private extension RNBundleManager {
    func checkRollback() {
        store.incrementFailures()
        if store.shouldRollback() {
            let fromVersion = store.state.currentVersion
            let failures = store.state.consecutiveFailures
            store.performRollback()
            reporter.report(BundleEvent(.rollback, [
                "deviceId": store.state.deviceId,
                "fromVersion": fromVersion,
                "toVersion": "",
                "consecutiveFailures": failures
            ]))
        }
    }

    func registerHealthObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(jsDidLoad),
            name: NSNotification.Name("RCTJavaScriptDidLoadNotification"),
            object: nil
        )
    }

    @objc func jsDidLoad() {
        markHealthy()
    }

    func handleConfig(_ config: UpdateConfig) {
        let result = resolver.resolve(
            config: config,
            deviceId: store.state.deviceId,
            appVersion: appVersion,
            currentVersion: store.state.currentVersion
        )

        switch result {
        case .update(let version, let bundle):
            let grayscaleHit = bundle.grayscale.whitelist.contains(store.state.deviceId) ? "whitelist" : "percentage"
            reporter.report(BundleEvent(.updateAvailable, [
                "deviceId": store.state.deviceId,
                "fromVersion": store.state.currentVersion,
                "toVersion": version,
                "grayscaleHit": grayscaleHit
            ]))
            downloadAndApply(version: version, bundle: bundle)

        case .noUpdate:
            reporter.report(BundleEvent(.noUpdate, [
                "deviceId": store.state.deviceId,
                "currentVersion": store.state.currentVersion
            ]))
        }
    }

    func downloadAndApply(version: String, bundle: BundleInfo) {
        reporter.report(BundleEvent(.downloadStart, [
            "deviceId": store.state.deviceId,
            "targetVersion": version
        ]))

        let startTime = Date()

        downloader.download(bundle: bundle, version: version) { [weak self] result in
            guard let self else { return }
            let duration = Int(Date().timeIntervalSince(startTime) * 1000)

            switch result {
            case .success:
                self.reporter.report(BundleEvent(.downloadSuccess, [
                    "deviceId": self.store.state.deviceId,
                    "targetVersion": version,
                    "fileSize": bundle.size,
                    "durationMs": duration
                ]))
                if bundle.applyMode == .immediate {
                    self.reporter.report(BundleEvent(.applyImmediate, [
                        "deviceId": self.store.state.deviceId,
                        "version": version
                    ]))
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .rnBundleDidUpdate, object: nil)
                    }
                }

            case .failure(let error):
                let errorType: String
                let errorMsg: String
                switch error {
                case .sha256Mismatch(let expected, let actual):
                    errorType = "sha256_mismatch"
                    errorMsg = "expected=\(expected) actual=\(actual)"
                case .networkError(let err):
                    errorType = "network"
                    errorMsg = err.localizedDescription
                case .fileError(let err):
                    errorType = "file"
                    errorMsg = err.localizedDescription
                }
                self.reporter.report(BundleEvent(.downloadFail, [
                    "deviceId": self.store.state.deviceId,
                    "targetVersion": version,
                    "errorType": errorType,
                    "errorMsg": errorMsg
                ]))
            }
        }
    }

    func startPolling() {
        reporter.report(BundleEvent(.pollingStart, [
            "intervalMinutes": Int(pollInterval / 60)
        ]))
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pollTimer?.invalidate()
            self.pollTimer = Timer.scheduledTimer(withTimeInterval: self.pollInterval, repeats: true) { [weak self] _ in
                self?.checkUpdate()
            }
        }
    }
}

// MARK: - Notification

public extension Notification.Name {
    static let rnBundleDidUpdate = Notification.Name("RNBundleDidUpdate")
}
