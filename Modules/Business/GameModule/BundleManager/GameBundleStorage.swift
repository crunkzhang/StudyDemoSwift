import Foundation

public final class GameBundleStorage {
    private let rootDir: URL
    private let fm = FileManager.default

    public init(rootDir: URL = GameBundleStorage.defaultRootDir()) {
        self.rootDir = rootDir
        try? fm.createDirectory(at: rootDir, withIntermediateDirectories: true)
    }

    public static func defaultRootDir() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("Games", isDirectory: true)
    }

    // MARK: - 路径计算

    /// Documents/Games/{gameId}/{version}/
    public func gameDir(id: String, version: String) -> URL {
        rootDir.appendingPathComponent(id, isDirectory: true)
            .appendingPathComponent(version, isDirectory: true)
    }

    /// Documents/Games/{gameId}/{version}/index.html
    public func indexHTMLURL(id: String, version: String) -> URL {
        gameDir(id: id, version: version).appendingPathComponent("index.html")
    }

    /// 该游戏该版本是否已下载并解压完成
    public func hasBundle(id: String, version: String) -> Bool {
        fm.fileExists(atPath: indexHTMLURL(id: id, version: version).path)
    }

    public func remove(id: String, version: String) throws {
        let dir = gameDir(id: id, version: version)
        if fm.fileExists(atPath: dir.path) {
            try fm.removeItem(at: dir)
        }
    }

    /// 列出某游戏所有已下载的版本(本地按字符串倒序,新版在前)
    public func listVersions(id: String) -> [String] {
        let gameRoot = rootDir.appendingPathComponent(id, isDirectory: true)
        guard let contents = try? fm.contentsOfDirectory(atPath: gameRoot.path) else {
            return []
        }
        return contents
            .filter {
                fm.fileExists(atPath: gameRoot.appendingPathComponent($0)
                                            .appendingPathComponent("index.html").path)
            }
            .sorted(by: >)
    }

    // MARK: - manifest 缓存

    private var manifestPath: URL {
        rootDir.appendingPathComponent("manifest.json")
    }

    public func saveManifest(_ manifest: GameManifest) throws {
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: manifestPath, options: .atomic)
    }

    public func loadManifest() -> GameManifest? {
        guard let data = try? Data(contentsOf: manifestPath) else { return nil }
        return try? JSONDecoder().decode(GameManifest.self, from: data)
    }
}
