import Foundation

/// 已下发 schema 的本地缓存,**保留当前 + 上一个版本**以支持回滚。
///   Documents/Pages/{id}.json        当前版
///   Documents/Pages/{id}.version
///   Documents/Pages/{id}.prev.json   上一版(回滚用)
///   Documents/Pages/{id}.prev.version
public final class PageSchemaStorage {
    private let rootDir: URL
    private let fm = FileManager.default

    public init(rootDir: URL = PageSchemaStorage.defaultRootDir()) {
        self.rootDir = rootDir
        try? fm.createDirectory(at: rootDir, withIntermediateDirectories: true)
    }

    public static func defaultRootDir() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("Pages", isDirectory: true)
    }

    private func curJSON(_ id: String) -> URL { rootDir.appendingPathComponent("\(id).json") }
    private func curVer(_ id: String) -> URL { rootDir.appendingPathComponent("\(id).version") }
    private func prevJSON(_ id: String) -> URL { rootDir.appendingPathComponent("\(id).prev.json") }
    private func prevVer(_ id: String) -> URL { rootDir.appendingPathComponent("\(id).prev.version") }
    private var manifestURL: URL { rootDir.appendingPathComponent("manifest.json") }

    // MARK: - 当前版

    public func currentData(_ id: String) -> Data? { try? Data(contentsOf: curJSON(id)) }
    public func currentVersion(_ id: String) -> String? { readString(curVer(id)) }

    /// 写入新版前,先把现有当前版降级为「上一版」,实现一键回滚。
    /// 仅在 schema 已校验通过后调用(落盘的都是可渲染的)。
    public func save(id: String, data: Data, version: String) {
        if let cur = currentData(id), let curV = currentVersion(id) {
            try? cur.write(to: prevJSON(id), options: .atomic)
            try? Data(curV.utf8).write(to: prevVer(id), options: .atomic)
        }
        try? data.write(to: curJSON(id), options: .atomic)
        try? Data(version.utf8).write(to: curVer(id), options: .atomic)
    }

    // MARK: - 上一版 / 回滚

    public func previousData(_ id: String) -> Data? { try? Data(contentsOf: prevJSON(id)) }
    public func previousVersion(_ id: String) -> String? { readString(prevVer(id)) }

    /// 把上一版提升为当前版(运行期发现新版有问题时的安全阀)。
    @discardableResult
    public func rollback(id: String) -> Bool {
        guard let pData = previousData(id), let pVer = previousVersion(id) else { return false }
        try? pData.write(to: curJSON(id), options: .atomic)
        try? Data(pVer.utf8).write(to: curVer(id), options: .atomic)
        try? fm.removeItem(at: prevJSON(id))
        try? fm.removeItem(at: prevVer(id))
        return true
    }

    // MARK: - manifest

    public func saveManifest(_ m: PageManifest) {
        if let d = try? JSONEncoder().encode(m) { try? d.write(to: manifestURL, options: .atomic) }
    }
    public func loadManifest() -> PageManifest? {
        guard let d = try? Data(contentsOf: manifestURL) else { return nil }
        return try? JSONDecoder().decode(PageManifest.self, from: d)
    }

    private func readString(_ url: URL) -> String? {
        guard let d = try? Data(contentsOf: url) else { return nil }
        return String(data: d, encoding: .utf8)
    }
}
