import Foundation

struct GrayscaleConfig: Codable {
    let percentage: Int
    let whitelist: [String]
    let minAppVersion: String
}

struct BundleInfo: Codable {
    let url: String
    let sha256: String
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
    let bundles: [String: BundleInfo]
}

enum VersionResolveResult {
    case update(version: String, bundle: BundleInfo)
    case noUpdate
}
