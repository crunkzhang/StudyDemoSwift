import Foundation

public struct GameManifest: Codable {
    public let manifestVersion: Int
    public let updatedAt: String
    public let games: [GameEntry]

    public init(manifestVersion: Int, updatedAt: String, games: [GameEntry]) {
        self.manifestVersion = manifestVersion
        self.updatedAt = updatedAt
        self.games = games
    }
}

public struct GameEntry: Codable {
    public let id: String
    public let title: String
    /// 大厅卡片上的一句话描述(如"经典数字合并")
    public let subtitle: String?
    public let icon: String
    public let version: String
    public let url: String
    public let sha256: String
    public let size: Int
    /// 游戏背景色 hex(如 "#FAF8EF"),用于 Runner 容器底色,避免 H5 加载空隙黑屏
    public let backgroundColor: String?
    /// 游戏需要的原生能力,如 ["bridge"](需 JS Bridge 调用原生 AI);nil 表示纯 web 游戏
    public let capabilities: [String]?
    public let grayscale: Grayscale?

    public init(id: String, title: String, subtitle: String? = nil,
                icon: String, version: String,
                url: String, sha256: String, size: Int,
                backgroundColor: String? = nil, capabilities: [String]? = nil,
                grayscale: Grayscale? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.version = version
        self.url = url
        self.sha256 = sha256
        self.size = size
        self.backgroundColor = backgroundColor
        self.capabilities = capabilities
        self.grayscale = grayscale
    }
}

public struct Grayscale: Codable {
    public let percentage: Int
    public let whitelist: [String]

    public init(percentage: Int, whitelist: [String]) {
        self.percentage = percentage
        self.whitelist = whitelist
    }
}
