import Foundation

/// 页面下发清单:页面 id → schema 地址 + 版本 + 校验 + 灰度。
public struct PageManifest: Codable {
    public let manifestVersion: Int
    public let pages: [PageEntry]
}

public struct PageEntry: Codable {
    public let id: String
    public let version: String
    public let url: String
    public let sha256: String
    /// 渲染该页所需最低客户端能力版本
    public let minClient: Int?
    public let grayscale: DSLGrayscale?
}

public struct DSLGrayscale: Codable {
    public let percentage: Int
    public let whitelist: [String]
}
