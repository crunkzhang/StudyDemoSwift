import Foundation

/// 全局 API 环境。
/// - Debug：优先读 `UserDefaults["app.api.env"]`（Debug 面板写入），否则 `.dev`
/// - Release：读 Info.plist 的 `API_ENV`（由 xcconfig 注入），否则 `.prod`
public enum AppEnvironment {
    private static let overrideKey = "app.api.env"

    public static var current: APIEnv = {
        #if DEBUG
        if let raw = UserDefaults.standard.string(forKey: overrideKey),
           let env = APIEnv(rawValue: raw) {
            return env
        }
        return .dev
        #else
        if let raw = Bundle.main.infoDictionary?["API_ENV"] as? String,
           let env = APIEnv(rawValue: raw) {
            return env
        }
        return .prod
        #endif
    }()

    #if DEBUG
    /// Debug 面板切换环境，写入后需重启进程生效。
    public static func setOverride(_ env: APIEnv) {
        UserDefaults.standard.set(env.rawValue, forKey: overrideKey)
    }

    public static func clearOverride() {
        UserDefaults.standard.removeObject(forKey: overrideKey)
    }
    #endif
}
