import UIKit
import AIKit

/// 系统能力 Bridge:触觉反馈 sys.haptic({style}) + AI 厂商切换 sys.getProviders / sys.setProvider。
public final class SysBridgeHandler: GameBridgeHandler {
    public let namespace = "sys"

    public init() {}

    public func handle(method: String, params: [String: Any]) async -> BridgeResult {
        switch method {
        case "sys.haptic":
            let style = params["style"] as? String ?? "medium"
            await MainActor.run { Self.fire(style) }
            return .success([:])

        case "sys.getProviders":
            let list = AIVendor.allCases.map { ["id": $0.rawValue, "name": $0.displayName] }
            return .success(["current": AIConfig.current.rawValue, "list": list])

        case "sys.setProvider":
            guard let id = params["id"] as? String, let vendor = AIVendor(rawValue: id) else {
                return .failure(code: "BAD_PARAMS", message: "未知厂商")
            }
            AIConfig.select(vendor)
            return .success(["current": vendor.rawValue])

        default:
            return .failure(code: "UNKNOWN_METHOD", message: method)
        }
    }

    @MainActor
    private static func fire(_ style: String) {
        switch style {
        case "success", "warning", "error":
            let g = UINotificationFeedbackGenerator()
            let type: UINotificationFeedbackGenerator.FeedbackType =
                style == "success" ? .success : (style == "warning" ? .warning : .error)
            g.notificationOccurred(type)
        default:
            let s: UIImpactFeedbackGenerator.FeedbackStyle =
                style == "light" ? .light : (style == "heavy" ? .heavy : .medium)
            UIImpactFeedbackGenerator(style: s).impactOccurred()
        }
    }
}
