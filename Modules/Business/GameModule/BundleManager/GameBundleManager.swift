import Foundation
import UIKit

public final class GameBundleManager {
    public static let shared = GameBundleManager()

    private let storage: GameBundleStorage
    private let downloader: GameDownloader
    private var remoteURL: URL?
    private var pollTimer: Timer?

    /// 当前 manifest 缓存(供大厅渲染 + 注入 H5)
    public private(set) var currentManifest: GameManifest?

    /// 同 gameId 并发请求合并(避免重复下载)
    private var inFlightDownloads: [String: Task<URL?, Never>] = [:]
    private let lock = NSLock()

    public init(storage: GameBundleStorage = GameBundleStorage(),
                downloader: GameDownloader = GameDownloader()) {
        self.storage = storage
        self.downloader = downloader
        // 启动时加载磁盘缓存
        self.currentManifest = storage.loadManifest()
    }

    /// AppDelegate 启动调,触发后台拉 manifest + 30min 轮询
    public func start(remoteURL: String) {
        guard let url = URL(string: remoteURL) else { return }
        self.remoteURL = url

        Task { await self.refreshManifest() }

        DispatchQueue.main.async { [weak self] in
            self?.pollTimer?.invalidate()
            self?.pollTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
                Task { await self?.refreshManifest() }
            }
        }
    }

    /// 拉远程 manifest → 写本地缓存 → 更新 currentManifest
    public func refreshManifest() async {
        guard let url = remoteURL else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                print("[Game] manifest fetch HTTP \(http.statusCode)")
                return
            }
            let manifest = try JSONDecoder().decode(GameManifest.self, from: data)
            try storage.saveManifest(manifest)
            currentManifest = manifest
            print("[Game] ✅ manifest refreshed, games=\(manifest.games.count)")
        } catch {
            print("[Game] ❌ manifest refresh failed: \(error)")
        }
    }

    /// 拿某个游戏的本地 index.html 路径(命中本地直接返回,否则下载)
    public func bundleURL(for gameId: String) async -> URL? {
        guard let game = currentManifest?.games.first(where: { $0.id == gameId }) else {
            print("[Game] \(gameId) 不在 manifest")
            return nil
        }
        // 灰度未命中 → 跳过下载
        guard Self.grayscaleHit(game: game) else {
            print("[Game] \(gameId) 灰度未命中,跳过下载")
            return nil
        }

        // 已下载 → 直接返回
        if storage.hasBundle(id: gameId, version: game.version) {
            return storage.indexHTMLURL(id: gameId, version: game.version)
        }

        // 并发请求合并
        lock.lock()
        if let inFlight = inFlightDownloads[gameId] {
            lock.unlock()
            return await inFlight.value
        }
        let task = Task<URL?, Never> { [weak self] in
            await self?.performDownload(game: game)
        }
        inFlightDownloads[gameId] = task
        lock.unlock()

        let result = await task.value
        lock.lock()
        inFlightDownloads.removeValue(forKey: gameId)
        lock.unlock()
        return result
    }

    /// 回退到本地上一个版本(当前版本加载失败时用)
    public func fallbackBundleURL(for gameId: String) -> URL? {
        guard let currentVersion = currentManifest?.games.first(where: { $0.id == gameId })?.version else {
            return nil
        }
        let versions = storage.listVersions(id: gameId)
        guard let prev = versions.first(where: { $0 != currentVersion }) else {
            return nil
        }
        print("[Game] 回退到本地版本 \(gameId) v\(prev)")
        return storage.indexHTMLURL(id: gameId, version: prev)
    }

    private func performDownload(game: GameEntry) async -> URL? {
        guard let url = URL(string: game.url) else { return nil }
        let destination = storage.gameDir(id: game.id, version: game.version)
        do {
            try await downloader.download(
                url: url,
                expectedSHA256: game.sha256,
                destination: destination
            )
            print("[Game] ✅ 下载完成 \(game.id) v\(game.version)")
            return storage.indexHTMLURL(id: game.id, version: game.version)
        } catch {
            print("[Game] ❌ 下载失败 \(game.id) v\(game.version): \(error)")
            return nil
        }
    }

    // MARK: - 灰度命中

    private static let deviceIdKey = "GameModule.deviceId"
    static var deviceId: String {
        if let cached = UserDefaults.standard.string(forKey: deviceIdKey) {
            return cached
        }
        let new = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(new, forKey: deviceIdKey)
        return new
    }

    /// 灰度命中:白名单或 deviceId hash % 100 < percentage。
    /// 无 grayscale 字段视为 100% 命中。
    static func grayscaleHit(game: GameEntry) -> Bool {
        guard let g = game.grayscale else { return true }
        if g.whitelist.contains(deviceId) { return true }
        let hash = abs(deviceId.unicodeScalars.reduce(0) { $0 &+ Int($1.value) })
        return hash % 100 < g.percentage
    }
}
