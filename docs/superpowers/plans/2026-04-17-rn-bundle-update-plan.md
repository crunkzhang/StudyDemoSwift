# RN Bundle 远程热更新 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将现有最小闭环 RN bundle 远程加载升级为具备灰度发布、白名单、自动回滚、监控埋点的企业级热更新方案。

**Architecture:** OSS 上一个 `update-config.json` 包含所有发布策略。客户端拉取后，由 `BundleVersionResolver` 决定目标版本，`BundleDownloader` 负责下载校验，`BundleMetadata` 管理本地状态和自动回滚，`BundleMonitorReporter` 负责埋点。`RNBundleManager` 是对外唯一入口，协调所有模块。

**Tech Stack:** Swift, URLSession, CommonCrypto (MD5), React Native Bridge notifications

**Spec:** `docs/superpowers/specs/2026-04-17-rn-bundle-update-design.md`

---

## File Structure

```
Modules/WeChatKit/WeChatRN/
├── RNBundleUpdate/                      ← 新建目录
│   ├── BundleModels.swift               ← 数据模型（UpdateConfig, BundleInfo, GrayscaleConfig）
│   ├── BundleMetadata.swift             ← metadata.json 读写 + 回滚计数
│   ├── BundleMonitorReporter.swift      ← 事件枚举 + Reporter 协议 + Console 实现
│   ├── BundleConfigFetcher.swift        ← 网络请求 update-config.json
│   ├── BundleVersionResolver.swift      ← 灰度/白名单/版本约束 → 确定目标版本
│   ├── BundleDownloader.swift           ← 下载 + MD5 校验 + 原子写入
│   └── RNBundleManager.swift            ← 对外入口，协调各模块
├── RNFactoryManager.swift               ← 改动：bundleURL() 读 BundleManager
├── RNBundleUpdater.swift                ← 删除
└── ...existing files...

WeChatSwift/
├── AppDelegate.swift                    ← 改动：替换 RNBundleUpdater 为 RNBundleManager
├── SceneDelegate.swift                  ← 改动：添加 sceneWillEnterForeground
└── ...existing files...
```

---

### Task 1: BundleModels — 数据模型

**Files:**
- Create: `Modules/WeChatKit/WeChatRN/RNBundleUpdate/BundleModels.swift`

- [ ] **Step 1: Create directory and file**

```bash
mkdir -p Modules/WeChatKit/WeChatRN/RNBundleUpdate
```

```swift
// BundleModels.swift
import Foundation

struct GrayscaleConfig: Codable {
    let percentage: Int
    let whitelist: [String]
    let minAppVersion: String
}

struct BundleInfo: Codable {
    let url: String
    let md5: String
    let size: Int
    let releaseNotes: String
    let applyMode: ApplyMode
    let grayscale: GrayscaleConfig

    enum ApplyMode: String, Codable {
        case nextLaunch
        case immediate
    }
}

struct UpdateConfig: Codable {
    let latestVersion: Int
    let minAppVersion: String
    let bundles: [String: BundleInfo]
}

enum VersionResolveResult {
    case update(version: Int, bundle: BundleInfo)
    case noUpdate
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/a1021500055/Study/HelloRN/WeChatSwift && pod install && xcodebuild -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Modules/WeChatKit/WeChatRN/RNBundleUpdate/BundleModels.swift
git commit -m "feat(bundle-update): add BundleModels data models"
```

---

### Task 2: BundleMetadata — 本地状态管理

**Files:**
- Create: `Modules/WeChatKit/WeChatRN/RNBundleUpdate/BundleMetadata.swift`

- [ ] **Step 1: Create file**

```swift
// BundleMetadata.swift
import Foundation

struct BundleMetadataState: Codable {
    var currentVersion: Int
    var lastHealthyVersion: Int
    var md5: String
    var consecutiveFailures: Int
    var lastCheckTime: TimeInterval
    var deviceId: String

    static let empty = BundleMetadataState(
        currentVersion: 0,
        lastHealthyVersion: 0,
        md5: "",
        consecutiveFailures: 0,
        lastCheckTime: 0,
        deviceId: UUID().uuidString
    )
}

final class BundleMetadata {
    private let baseDir: URL
    private let metadataURL: URL
    private(set) var state: BundleMetadataState

    var currentDir: URL { baseDir.appendingPathComponent("current", isDirectory: true) }
    var downloadingDir: URL { baseDir.appendingPathComponent("downloading", isDirectory: true) }

    var currentBundlePath: URL? {
        let url = currentDir.appendingPathComponent("main.jsbundle")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        baseDir = docs.appendingPathComponent("RNBundle", isDirectory: true)
        metadataURL = baseDir.appendingPathComponent("metadata.json")

        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)

        if let data = try? Data(contentsOf: metadataURL),
           let loaded = try? JSONDecoder().decode(BundleMetadataState.self, from: data) {
            state = loaded
        } else {
            state = .empty
            save()
        }
    }

    func save() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: metadataURL, options: .atomic)
    }

    func incrementFailures() {
        state.consecutiveFailures += 1
        save()
    }

    func markHealthy() {
        state.consecutiveFailures = 0
        state.lastHealthyVersion = state.currentVersion
        save()
    }

    func updateVersion(_ version: Int, md5: String) {
        state.currentVersion = version
        state.md5 = md5
        state.consecutiveFailures = 0
        save()
    }

    func updateCheckTime() {
        state.lastCheckTime = Date().timeIntervalSince1970
        save()
    }

    func shouldRollback() -> Bool {
        state.consecutiveFailures >= 3 && state.currentVersion > 0
    }

    func performRollback() {
        let bundlePath = currentDir.appendingPathComponent("main.jsbundle")
        try? FileManager.default.removeItem(at: bundlePath)
        state.currentVersion = 0
        state.md5 = ""
        state.consecutiveFailures = 0
        save()
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/a1021500055/Study/HelloRN/WeChatSwift && xcodebuild -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Modules/WeChatKit/WeChatRN/RNBundleUpdate/BundleMetadata.swift
git commit -m "feat(bundle-update): add BundleMetadata local state management"
```

---

### Task 3: BundleMonitorReporter — 监控埋点

**Files:**
- Create: `Modules/WeChatKit/WeChatRN/RNBundleUpdate/BundleMonitorReporter.swift`

- [ ] **Step 1: Create file**

```swift
// BundleMonitorReporter.swift
import Foundation

enum BundleEventType: String {
    case checkUpdate = "check_update"
    case updateAvailable = "update_available"
    case downloadStart = "download_start"
    case downloadSuccess = "download_success"
    case downloadFail = "download_fail"
    case loadSuccess = "load_success"
    case loadFail = "load_fail"
    case rollback = "rollback"
    case applyImmediate = "apply_immediate"
}

struct BundleEvent {
    let type: BundleEventType
    let params: [String: Any]

    init(_ type: BundleEventType, _ params: [String: Any] = [:]) {
        self.type = type
        self.params = params
    }
}

protocol BundleEventReporter {
    func report(_ event: BundleEvent)
}

final class ConsoleBundleReporter: BundleEventReporter {
    func report(_ event: BundleEvent) {
        let paramsStr = event.params.map { "\($0.key)=\($0.value)" }.joined(separator: " | ")
        if paramsStr.isEmpty {
            print("[BundleMonitor] \(event.type.rawValue)")
        } else {
            print("[BundleMonitor] \(event.type.rawValue) | \(paramsStr)")
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/a1021500055/Study/HelloRN/WeChatSwift && xcodebuild -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Modules/WeChatKit/WeChatRN/RNBundleUpdate/BundleMonitorReporter.swift
git commit -m "feat(bundle-update): add BundleMonitorReporter with console reporter"
```

---

### Task 4: BundleConfigFetcher — 拉取远程配置

**Files:**
- Create: `Modules/WeChatKit/WeChatRN/RNBundleUpdate/BundleConfigFetcher.swift`

- [ ] **Step 1: Create file**

```swift
// BundleConfigFetcher.swift
import Foundation

final class BundleConfigFetcher {
    enum FetchError: Error {
        case invalidURL
        case networkError(Error)
        case decodingError(Error)
    }

    func fetch(remoteURL: String, completion: @escaping (Result<UpdateConfig, FetchError>) -> Void) {
        guard let url = URL(string: "\(remoteURL)/update-config.json") else {
            completion(.failure(.invalidURL))
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error {
                completion(.failure(.networkError(error)))
                return
            }
            guard let data else {
                completion(.failure(.networkError(NSError(domain: "BundleConfigFetcher", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data"]))))
                return
            }
            do {
                let config = try JSONDecoder().decode(UpdateConfig.self, from: data)
                completion(.success(config))
            } catch {
                completion(.failure(.decodingError(error)))
            }
        }.resume()
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/a1021500055/Study/HelloRN/WeChatSwift && xcodebuild -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Modules/WeChatKit/WeChatRN/RNBundleUpdate/BundleConfigFetcher.swift
git commit -m "feat(bundle-update): add BundleConfigFetcher for remote config"
```

---

### Task 5: BundleVersionResolver — 灰度/白名单/版本决策

**Files:**
- Create: `Modules/WeChatKit/WeChatRN/RNBundleUpdate/BundleVersionResolver.swift`

- [ ] **Step 1: Create file**

```swift
// BundleVersionResolver.swift
import Foundation
import CommonCrypto

final class BundleVersionResolver {

    func resolve(config: UpdateConfig, deviceId: String, appVersion: String, currentVersion: Int) -> VersionResolveResult {
        // 全局 app 版本检查
        guard compareVersions(appVersion, isAtLeast: config.minAppVersion) else {
            return .noUpdate
        }

        // 从最新版本开始，逐版本检查
        let sortedVersions = config.bundles.keys
            .compactMap { Int($0) }
            .sorted(by: >)

        for version in sortedVersions {
            guard let bundle = config.bundles[String(version)] else { continue }

            // app 版本不满足该 bundle 的要求
            guard compareVersions(appVersion, isAtLeast: bundle.grayscale.minAppVersion) else { continue }

            // 和当前版本相同，不需要更新
            guard version != currentVersion else { return .noUpdate }

            // 白名单命中
            if bundle.grayscale.whitelist.contains(deviceId) {
                return .update(version: version, bundle: bundle)
            }

            // 灰度比例判断
            if isInGrayscale(deviceId: deviceId, percentage: bundle.grayscale.percentage) {
                return .update(version: version, bundle: bundle)
            }

            // 未命中灰度，继续检查更早的全量版本
        }

        return .noUpdate
    }

    private func isInGrayscale(deviceId: String, percentage: Int) -> Bool {
        guard percentage > 0 else { return false }
        guard percentage < 100 else { return true }
        let hash = abs(stableHash(deviceId))
        return hash % 100 < percentage
    }

    private func stableHash(_ string: String) -> Int {
        let data = Data(string.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { bytes in
            _ = CC_MD5(bytes.baseAddress, CC_LONG(data.count), &digest)
        }
        let value = digest.prefix(4).enumerated().reduce(0) { result, pair in
            result | (Int(pair.element) << (pair.offset * 8))
        }
        return abs(value)
    }

    private func compareVersions(_ version: String, isAtLeast minVersion: String) -> Bool {
        let v1 = version.split(separator: ".").compactMap { Int($0) }
        let v2 = minVersion.split(separator: ".").compactMap { Int($0) }
        let count = max(v1.count, v2.count)
        for i in 0..<count {
            let a = i < v1.count ? v1[i] : 0
            let b = i < v2.count ? v2[i] : 0
            if a < b { return false }
            if a > b { return true }
        }
        return true
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/a1021500055/Study/HelloRN/WeChatSwift && xcodebuild -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Modules/WeChatKit/WeChatRN/RNBundleUpdate/BundleVersionResolver.swift
git commit -m "feat(bundle-update): add BundleVersionResolver with grayscale/whitelist"
```

---

### Task 6: BundleDownloader — 下载 + MD5 校验 + 原子写入

**Files:**
- Create: `Modules/WeChatKit/WeChatRN/RNBundleUpdate/BundleDownloader.swift`

- [ ] **Step 1: Create file**

```swift
// BundleDownloader.swift
import Foundation
import CommonCrypto

final class BundleDownloader {
    enum DownloadError: Error {
        case networkError(Error)
        case md5Mismatch(expected: String, actual: String)
        case fileError(Error)
    }

    private let metadata: BundleMetadata

    init(metadata: BundleMetadata) {
        self.metadata = metadata
    }

    func download(bundle: BundleInfo, version: Int, completion: @escaping (Result<Void, DownloadError>) -> Void) {
        guard let url = URL(string: bundle.url) else {
            completion(.failure(.networkError(NSError(domain: "BundleDownloader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))))
            return
        }

        let downloadingDir = metadata.downloadingDir
        try? FileManager.default.createDirectory(at: downloadingDir, withIntermediateDirectories: true)
        let tmpPath = downloadingDir.appendingPathComponent("main.jsbundle.tmp")

        URLSession.shared.downloadTask(with: url) { [weak self] tempURL, _, error in
            guard let self else { return }

            if let error {
                completion(.failure(.networkError(error)))
                return
            }
            guard let tempURL else {
                completion(.failure(.networkError(NSError(domain: "BundleDownloader", code: -2, userInfo: [NSLocalizedDescriptionKey: "No temp file"]))))
                return
            }

            do {
                // Move to our downloading directory
                if FileManager.default.fileExists(atPath: tmpPath.path) {
                    try FileManager.default.removeItem(at: tmpPath)
                }
                try FileManager.default.moveItem(at: tempURL, to: tmpPath)

                // MD5 verify
                let actualMD5 = self.md5(of: tmpPath)
                guard actualMD5 == bundle.md5 else {
                    try? FileManager.default.removeItem(at: tmpPath)
                    completion(.failure(.md5Mismatch(expected: bundle.md5, actual: actualMD5)))
                    return
                }

                // Atomic move to current
                let currentDir = self.metadata.currentDir
                try FileManager.default.createDirectory(at: currentDir, withIntermediateDirectories: true)
                let destPath = currentDir.appendingPathComponent("main.jsbundle")
                if FileManager.default.fileExists(atPath: destPath.path) {
                    try FileManager.default.removeItem(at: destPath)
                }
                try FileManager.default.moveItem(at: tmpPath, to: destPath)

                // Update metadata
                self.metadata.updateVersion(version, md5: bundle.md5)

                completion(.success(()))
            } catch {
                try? FileManager.default.removeItem(at: tmpPath)
                completion(.failure(.fileError(error)))
            }
        }.resume()
    }

    private func md5(of url: URL) -> String {
        guard let data = try? Data(contentsOf: url) else { return "" }
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { bytes in
            _ = CC_MD5(bytes.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/a1021500055/Study/HelloRN/WeChatSwift && xcodebuild -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Modules/WeChatKit/WeChatRN/RNBundleUpdate/BundleDownloader.swift
git commit -m "feat(bundle-update): add BundleDownloader with MD5 verification"
```

---

### Task 7: RNBundleManager — 对外入口，协调所有模块

**Files:**
- Create: `Modules/WeChatKit/WeChatRN/RNBundleUpdate/RNBundleManager.swift`

- [ ] **Step 1: Create file**

```swift
// RNBundleManager.swift
import Foundation

public final class RNBundleManager {
    public static let shared = RNBundleManager()

    private var remoteURL: String = ""
    private var appVersion: String = "1.0.0"

    private let metadata = BundleMetadata()
    private let fetcher = BundleConfigFetcher()
    private let resolver = BundleVersionResolver()
    private lazy var downloader = BundleDownloader(metadata: metadata)

    var reporter: BundleEventReporter = ConsoleBundleReporter()

    private var isChecking = false
    private var pollTimer: Timer?
    private var pollInterval: TimeInterval = 30 * 60

    public var bundlePath: URL? {
        metadata.currentBundlePath
    }

    private init() {}

    public func configure(remoteURL: String, appVersion: String) {
        self.remoteURL = remoteURL
        self.appVersion = appVersion
    }

    public func start() {
        checkRollback()
        registerHealthObserver()
        checkUpdate()
        startPolling()
    }

    public func checkUpdate() {
        guard !remoteURL.isEmpty else { return }
        guard !isChecking else { return }

        // Throttle: 60 seconds between checks
        let now = Date().timeIntervalSince1970
        guard now - metadata.state.lastCheckTime >= 60 else { return }

        isChecking = true
        metadata.updateCheckTime()

        reporter.report(BundleEvent(.checkUpdate, [
            "deviceId": metadata.state.deviceId,
            "currentVersion": metadata.state.currentVersion,
            "appVersion": appVersion
        ]))

        fetcher.fetch(remoteURL: remoteURL) { [weak self] result in
            guard let self else { return }
            defer { self.isChecking = false }

            switch result {
            case .success(let config):
                self.handleConfig(config)
            case .failure(let error):
                self.reporter.report(BundleEvent(.downloadFail, [
                    "errorType": "config_fetch",
                    "errorMsg": "\(error)"
                ]))
            }
        }
    }

    public func markHealthy() {
        metadata.markHealthy()
        reporter.report(BundleEvent(.loadSuccess, [
            "deviceId": metadata.state.deviceId,
            "version": metadata.state.currentVersion,
            "source": metadata.state.currentVersion > 0 ? "downloaded" : "builtin"
        ]))
    }

    // MARK: - Private

    private func checkRollback() {
        metadata.incrementFailures()
        if metadata.shouldRollback() {
            let fromVersion = metadata.state.currentVersion
            metadata.performRollback()
            reporter.report(BundleEvent(.rollback, [
                "deviceId": metadata.state.deviceId,
                "fromVersion": fromVersion,
                "toVersion": 0,
                "consecutiveFailures": 3
            ]))
        }
    }

    private func registerHealthObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(jsDidLoad),
            name: NSNotification.Name("RCTJavaScriptDidLoadNotification"),
            object: nil
        )
    }

    @objc private func jsDidLoad() {
        markHealthy()
    }

    private func handleConfig(_ config: UpdateConfig) {
        let result = resolver.resolve(
            config: config,
            deviceId: metadata.state.deviceId,
            appVersion: appVersion,
            currentVersion: metadata.state.currentVersion
        )

        switch result {
        case .update(let version, let bundle):
            let grayscaleHit = bundle.grayscale.whitelist.contains(metadata.state.deviceId) ? "whitelist" : "percentage"
            reporter.report(BundleEvent(.updateAvailable, [
                "deviceId": metadata.state.deviceId,
                "fromVersion": metadata.state.currentVersion,
                "toVersion": version,
                "grayscaleHit": grayscaleHit
            ]))
            downloadAndApply(version: version, bundle: bundle)

        case .noUpdate:
            break
        }
    }

    private func downloadAndApply(version: Int, bundle: BundleInfo) {
        reporter.report(BundleEvent(.downloadStart, [
            "deviceId": metadata.state.deviceId,
            "targetVersion": version
        ]))

        let startTime = Date()

        downloader.download(bundle: bundle, version: version) { [weak self] result in
            guard let self else { return }
            let duration = Int(Date().timeIntervalSince(startTime) * 1000)

            switch result {
            case .success:
                self.reporter.report(BundleEvent(.downloadSuccess, [
                    "deviceId": self.metadata.state.deviceId,
                    "targetVersion": version,
                    "fileSize": bundle.size,
                    "durationMs": duration
                ]))
                if bundle.applyMode == .immediate {
                    self.reporter.report(BundleEvent(.applyImmediate, [
                        "deviceId": self.metadata.state.deviceId,
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
                case .md5Mismatch(let expected, let actual):
                    errorType = "md5_mismatch"
                    errorMsg = "expected=\(expected) actual=\(actual)"
                case .networkError(let err):
                    errorType = "network"
                    errorMsg = err.localizedDescription
                case .fileError(let err):
                    errorType = "file"
                    errorMsg = err.localizedDescription
                }
                self.reporter.report(BundleEvent(.downloadFail, [
                    "deviceId": self.metadata.state.deviceId,
                    "targetVersion": version,
                    "errorType": errorType,
                    "errorMsg": errorMsg
                ]))
            }
        }
    }

    private func startPolling() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pollTimer?.invalidate()
            self.pollTimer = Timer.scheduledTimer(withTimeInterval: self.pollInterval, repeats: true) { [weak self] _ in
                self?.checkUpdate()
            }
        }
    }
}

public extension Notification.Name {
    static let rnBundleDidUpdate = Notification.Name("RNBundleDidUpdate")
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/a1021500055/Study/HelloRN/WeChatSwift && xcodebuild -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Modules/WeChatKit/WeChatRN/RNBundleUpdate/RNBundleManager.swift
git commit -m "feat(bundle-update): add RNBundleManager as coordinator"
```

---

### Task 8: 集成改造 — 替换旧代码，接入新模块

**Files:**
- Modify: `Modules/WeChatKit/WeChatRN/RNFactoryManager.swift`
- Modify: `WeChatSwift/AppDelegate.swift`
- Modify: `WeChatSwift/SceneDelegate.swift`
- Delete: `Modules/WeChatKit/WeChatRN/RNBundleUpdater.swift`

- [ ] **Step 1: Modify RNFactoryManager.swift**

Replace the `#else` branch in `bundleURL()`:

```swift
// RNFactoryManager.swift — bundleURL() method, #else branch only:
    #else
        if let downloaded = RNBundleManager.shared.bundlePath {
            print("[RNBundle] 加载远程已下载 bundle: \(downloaded.path)")
            return downloaded
        }
        let builtin = Bundle.main.url(forResource: "main", withExtension: "jsbundle")
        print("[RNBundle] 加载内置兜底 bundle")
        return builtin
    #endif
```

(This is the same logic as before, just referencing `RNBundleManager` instead of `RNBundleUpdater`.)

- [ ] **Step 2: Modify AppDelegate.swift**

Replace the `RNBundleUpdater` lines:

```swift
// Before:
RNBundleUpdater.shared.remoteBaseURL = "https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com/ios/v1"
RNBundleUpdater.shared.checkUpdate()

// After:
RNBundleManager.shared.configure(
    remoteURL: "https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com",
    appVersion: "1.0.0"
)
RNBundleManager.shared.start()
```

- [ ] **Step 3: Modify SceneDelegate.swift**

Add `import WeChatRN` and `sceneWillEnterForeground`:

```swift
import UIKit
import WeChatRN

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = MainTabBarController()
        window.makeKeyAndVisible()
        self.window = window
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        RNBundleManager.shared.checkUpdate()
    }
}
```

- [ ] **Step 4: Delete RNBundleUpdater.swift**

```bash
rm Modules/WeChatKit/WeChatRN/RNBundleUpdater.swift
```

- [ ] **Step 5: Run pod install and build**

```bash
cd /Users/a1021500055/Study/HelloRN/WeChatSwift && pod install
```

Run: `xcodebuild -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat(bundle-update): integrate RNBundleManager, remove RNBundleUpdater"
```

---

### Task 9: OSS 配置迁移 — 更新远程文件结构

**Files:**
- None (OSS operations + local config file for reference)

- [ ] **Step 1: Build bundle and compute MD5**

```bash
cd /Users/a1021500055/Study/HelloRN/WeChatRN
npx react-native bundle --platform ios --dev false --entry-file index.js --bundle-output bundle/ios/main.jsbundle --assets-dest bundle/ios/
md5 bundle/ios/main.jsbundle
```

Note the MD5 hash from the output.

- [ ] **Step 2: Create update-config.json locally**

Create `/Users/a1021500055/Study/HelloRN/WeChatRN/bundle/ios/update-config.json` with the actual MD5 from step 1:

```json
{
  "latestVersion": 1,
  "minAppVersion": "1.0.0",
  "bundles": {
    "1": {
      "url": "https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com/bundles/v1/main.jsbundle",
      "md5": "<ACTUAL_MD5_FROM_STEP_1>",
      "size": <ACTUAL_SIZE>,
      "releaseNotes": "初始版本",
      "applyMode": "nextLaunch",
      "grayscale": {
        "percentage": 100,
        "whitelist": [],
        "minAppVersion": "1.0.0"
      }
    }
  }
}
```

- [ ] **Step 3: Upload to OSS**

Via Aliyun OSS console:
1. Create directory `bundles/v1/` in the bucket
2. Upload `main.jsbundle` to `bundles/v1/`
3. Upload `update-config.json` to the bucket root
4. (Optional) Clean up old `ios/v1/` directory

- [ ] **Step 4: Verify OSS access**

```bash
curl -s https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com/update-config.json | python3 -m json.tool
curl -sI https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com/bundles/v1/main.jsbundle | head -3
```

Expected: JSON output with version info, and HTTP 200 for the bundle.

---

### Task 10: 端到端验证

- [ ] **Step 1: Debug 模式验证日志**

Run the app in Debug mode on simulator. Check Xcode console for:

```
[BundleMonitor] check_update | ...
[BundleMonitor] update_available | ... (if version differs)
[BundleMonitor] download_start | ...
[BundleMonitor] download_success | ...
```

Or `[BundleMonitor] check_update` followed by no update if already on latest.

- [ ] **Step 2: Release 模式验证 bundle 加载**

Switch scheme to Release. Run on simulator. Check console for:

```
[RNBundle] 加载远程已下载 bundle: ...
```

or

```
[RNBundle] 加载内置兜底 bundle
```

Verify RN pages render correctly.

- [ ] **Step 3: Test grayscale — update config to percentage=0**

Update `update-config.json` on OSS, set `latestVersion: 2`, add a v2 bundle entry with `percentage: 0`. Restart app. Verify no update is triggered (unless device is in whitelist).

- [ ] **Step 4: Test whitelist — add device ID**

1. Find your deviceId from console logs: `[BundleMonitor] check_update | deviceId=xxx`
2. Add it to v2's `whitelist` array in `update-config.json`
3. Re-upload config
4. Restart app
5. Verify update is downloaded despite percentage=0

- [ ] **Step 5: Test rollback**

1. Upload a corrupted `main.jsbundle` (e.g. empty file) as a new version to OSS
2. Update config with matching (wrong) MD5
3. Or: manually delete the real bundle from Documents and set `consecutiveFailures=2` in metadata.json
4. Restart app 3 times
5. Verify rollback event in logs: `[BundleMonitor] rollback | ...`

- [ ] **Step 6: Commit any fixes**

```bash
git add -A
git commit -m "fix(bundle-update): fixes from e2e testing"
```
