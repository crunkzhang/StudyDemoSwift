import UIKit

/// 系统能力 Bridge:目前提供触觉反馈 sys.haptic({style})。
/// style: light / medium / heavy / success / warning
public final class SysBridgeHandler: GameBridgeHandler {
    public let namespace = "sys"

    public init() {}

    public func handle(method: String, params: [String: Any]) async -> BridgeResult {
        switch method {
        case "sys.haptic":
            let style = params["style"] as? String ?? "medium"
            await MainActor.run { Self.fire(style) }
            return .success([:])
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
