import Foundation
import UIKit

/// 页面 schema 管理:内置兜底 + OSS 下发 + sha256 + 版本 + 灰度 + 回滚。
/// 模式照搬 GameBundleManager。
public final class PageSchemaManager {
    public static let shared = PageSchemaManager()

    private let storage: PageSchemaStorage
    private let downloader: PageSchemaDownloader
    private var remoteURL: URL?
    public private(set) var manifest: PageManifest?

    public init(storage: PageSchemaStorage = PageSchemaStorage(),
                downloader: PageSchemaDownloader = PageSchemaDownloader()) {
        self.storage = storage
        self.downloader = downloader
        self.manifest = storage.loadManifest()
    }

    /// AppDelegate 启动调:后台拉取 manifest + 各页 schema。
    public func start(remoteURL: String) {
        guard let url = URL(string: remoteURL) else { return }
        self.remoteURL = url
        Task { await refresh() }
    }

    /// 拉远程 manifest → 逐页下载校验落盘(只落「解析通过」的,天然回滚安全)。
    public func refresh() async {
        guard let url = remoteURL else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                print("[DSL] manifest HTTP \(http.statusCode)"); return
            }
            let m = try JSONDecoder().decode(PageManifest.self, from: data)
            storage.saveManifest(m); manifest = m

            for entry in m.pages {
                guard Self.grayscaleHit(entry) else { continue }
                if storage.version(entry.id) == entry.version { continue } // 已最新
                guard let surl = URL(string: entry.url) else { continue }
                do {
                    let schemaData = try await downloader.download(url: surl, expectedSHA256: entry.sha256)
                    // 解析校验通过才落盘
                    if (try? JSONDecoder().decode(DSLPage.self, from: schemaData)) != nil {
                        try storage.save(id: entry.id, data: schemaData, version: entry.version)
                        print("[DSL] ✅ 页面更新 \(entry.id) v\(entry.version)")
                    } else {
                        print("[DSL] ⚠️ \(entry.id) schema 解析失败,保留旧版")
                    }
                } catch {
                    print("[DSL] ❌ \(entry.id) 下载失败: \(error)")
                }
            }
        } catch {
            print("[DSL] ❌ manifest 刷新失败: \(error)")
        }
    }

    /// 同步取页面:① 下发缓存 ② 内置兜底。能力版本不支持则跳过。
    public func page(for id: String) -> DSLPage? {
        if let data = storage.loadData(id), let page = decode(data), supported(page) {
            return page
        }
        // 内置兜底(静态库 + s.resources:先 main bundle 再 framework bundle)
        let bundles = [Bundle.main, Bundle(for: PageSchemaManager.self)]
        for b in bundles {
            if let url = b.url(forResource: id, withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let page = decode(data), supported(page) {
                return page
            }
        }
        return nil
    }

    private func decode(_ data: Data) -> DSLPage? {
        try? JSONDecoder().decode(DSLPage.self, from: data)
    }
    private func supported(_ page: DSLPage) -> Bool {
        (page.minClient ?? 1) <= DSLKit.capabilityVersion
    }

    // MARK: - 灰度命中

    private static let deviceIdKey = "DSLKit.deviceId"
    static var deviceId: String {
        if let cached = UserDefaults.standard.string(forKey: deviceIdKey) { return cached }
        let new = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(new, forKey: deviceIdKey)
        return new
    }
    static func grayscaleHit(_ entry: PageEntry) -> Bool {
        guard let g = entry.grayscale else { return true }
        if g.whitelist.contains(deviceId) { return true }
        let hash = abs(deviceId.unicodeScalars.reduce(0) { $0 &+ Int($1.value) })
        return hash % 100 < g.percentage
    }
}
