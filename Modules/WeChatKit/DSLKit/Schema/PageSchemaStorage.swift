import Foundation

/// 已下发 schema 的本地缓存:Documents/Pages/{id}.json + {id}.version。
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

    private func schemaURL(_ id: String) -> URL { rootDir.appendingPathComponent("\(id).json") }
    private func versionURL(_ id: String) -> URL { rootDir.appendingPathComponent("\(id).version") }
    private var manifestURL: URL { rootDir.appendingPathComponent("manifest.json") }

    public func loadData(_ id: String) -> Data? { try? Data(contentsOf: schemaURL(id)) }

    public func version(_ id: String) -> String? {
        guard let d = try? Data(contentsOf: versionURL(id)) else { return nil }
        return String(data: d, encoding: .utf8)
    }

    /// 仅在 schema 解析校验通过后调用(保证落盘的都是可渲染的,天然回滚安全)。
    public func save(id: String, data: Data, version: String) throws {
        try data.write(to: schemaURL(id), options: .atomic)
        try Data(version.utf8).write(to: versionURL(id), options: .atomic)
    }

    public func saveManifest(_ m: PageManifest) {
        if let d = try? JSONEncoder().encode(m) { try? d.write(to: manifestURL, options: .atomic) }
    }
    public func loadManifest() -> PageManifest? {
        guard let d = try? Data(contentsOf: manifestURL) else { return nil }
        return try? JSONDecoder().decode(PageManifest.self, from: d)
    }
}
