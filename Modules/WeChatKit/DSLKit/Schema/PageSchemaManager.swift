import Foundation
import UIKit

/// 页面 schema 管理:内置兜底 + OSS 下发 + sha256 + 版本 + 灰度 + 回滚 + 可观测。
///
/// 设计:
/// - `page(for:)` **同步**返回(VC 渲染需即时):走「内存缓存 → 磁盘当前版 → 内置兜底」,
///   仅返回**校验通过且可渲染**的页面。
/// - `refresh()` **去重**:并发调用(启动 + 每次进页)合并为同一个 in-flight 任务,
///   不重复打网络/写磁盘。
/// - 线程安全:内存缓存 + in-flight 用 `lock` 保护;磁盘写 `.atomic`。
///   (未用 actor 是为了保留 `page(for:)` 的同步语义。)
public final class PageSchemaManager {
    public static let shared = PageSchemaManager()

    public private(set) var config = PageSchemaConfig()
    public weak var observer: PageSchemaObserver?

    private let storage: PageSchemaStorage
    private var loader: SchemaLoader
    private var remoteURL: URL?

    private let lock = NSLock()
    private var cache: [String: DSLPage] = [:]   // 仅缓存校验通过、可渲染的页面
    private var inFlight: Task<Void, Never>?

    public init(storage: PageSchemaStorage = PageSchemaStorage()) {
        self.storage = storage
        self.loader = SchemaLoader(timeout: config.requestTimeout)
    }

    /// 注入配置(超时/能力版本/scheme 白名单)。建议 AppDelegate 启动时调用。
    public func configure(_ config: PageSchemaConfig) {
        self.config = config
        self.loader = SchemaLoader(timeout: config.requestTimeout)
        DSLAction.allowedSchemes = config.allowedSchemes
    }

    public func start(remoteURL: String) {
        guard let url = URL(string: remoteURL) else { return }
        self.remoteURL = url
        Task { await refresh() }
    }

    // MARK: - 读(同步)

    /// 取页面:内存缓存 → 磁盘当前版 → 内置兜底。仅返回可渲染页面,否则 nil。
    public func page(for id: String) -> DSLPage? {
        if let cached = lock.locked({ cache[id] }) { return cached }

        let (page, source) = loadBest(id)
        if let page { lock.locked { cache[id] = page } }
        if source != .remoteCache {
            observer?.schema(fallbackUsed: id, source: source)
        }
        return page
    }

    // MARK: - 刷新(去重)

    public func refresh() async {
        // 锁内原子地 check-and-set in-flight(Task 初始化不挂起,可在锁内创建)
        let (task, isOwner): (Task<Void, Never>, Bool) = lock.locked {
            if let existing = inFlight { return (existing, false) }
            let t = Task { await self.performRefresh() }
            inFlight = t
            return (t, true)
        }
        await task.value                          // 等待在锁外,不跨临界区
        if isOwner { lock.locked { inFlight = nil } }
    }

    /// 手动回退某页到上一个版本(运行期发现新版有问题时的安全阀)。
    @discardableResult
    public func rollback(pageId: String) -> Bool {
        guard storage.rollback(id: pageId) else { return false }
        let page = storage.currentData(pageId).flatMap { validated($0, id: pageId) }
        lock.locked { cache[pageId] = page }
        return true
    }

    // MARK: - 私有

    private func performRefresh() async {
        guard let url = remoteURL else { return }
        do {
            let manifest = try await loader.fetchManifest(url)
            storage.saveManifest(manifest)

            for entry in manifest.pages {
                guard Grayscale.hit(entry, deviceId: Self.deviceId) else { continue }
                guard storage.currentVersion(entry.id) != entry.version else { continue } // 已最新
                guard let surl = URL(string: entry.url) else { continue }
                do {
                    let data = try await loader.fetchSchema(url: surl, expectedSHA256: entry.sha256)
                    guard let page = validated(data, id: entry.id) else {
                        observer?.schema(validationFailed: entry.id, reason: "解析失败或无可渲染组件")
                        continue   // 保留旧版,不污染当前版
                    }
                    storage.save(id: entry.id, data: data, version: entry.version)
                    lock.locked { cache[entry.id] = page }
                    observer?.schema(didUpdate: entry.id, version: entry.version)
                } catch {
                    observer?.schema(refreshFailed: error)   // 单页失败不阻断其他页
                }
            }
        } catch {
            observer?.schema(refreshFailed: error)
        }
    }

    /// 磁盘当前版 → 内置兜底,均做校验。
    private func loadBest(_ id: String) -> (DSLPage?, PageSource) {
        if let data = storage.currentData(id), let page = validated(data, id: id) {
            return (page, .remoteCache)
        }
        let bundles = [Bundle.main, Bundle(for: PageSchemaManager.self)]
        for b in bundles {
            if let url = b.url(forResource: id, withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let page = validated(data, id: id) {
                return (page, .builtin)
            }
        }
        return (nil, .none)
    }

    /// 校验:① JSON 解析通过 ② minClient 能力支持 ③ 至少一个已知顶层组件
    /// (第③条挡掉「空页 / 全是未知组件」的坏 schema,防止渲染白页)。
    private func validated(_ data: Data, id: String) -> DSLPage? {
        guard let page = try? JSONDecoder().decode(DSLPage.self, from: data) else { return nil }
        guard (page.minClient ?? 1) <= config.capabilityVersion else { return nil }
        let hasRenderable = page.sections.contains { DSLComponentRegistry.shared.isKnown($0.type) }
        return hasRenderable ? page : nil
    }

    // MARK: - 设备标识 / 灰度(静态入口,便于测试与外部复用)

    private static let deviceIdKey = "DSLKit.deviceId"
    static var deviceId: String {
        if let cached = UserDefaults.standard.string(forKey: deviceIdKey) { return cached }
        let new = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(new, forKey: deviceIdKey)
        return new
    }
    static func grayscaleHit(_ entry: PageEntry) -> Bool {
        Grayscale.hit(entry, deviceId: deviceId)
    }
}

/// 同步作用域锁:在非 async 上下文里完成 lock/unlock,async 调用方只调此同步函数,
/// 规避「在 async 上下文直接 lock()/unlock()」的 Swift 6 限制。临界区内禁止 await。
private extension NSLock {
    @inline(__always) func locked<T>(_ body: () throws -> T) rethrows -> T {
        lock(); defer { unlock() }
        return try body()
    }
}
