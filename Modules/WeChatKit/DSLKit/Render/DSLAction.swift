import Foundation
import WeChatRouter

/// 动作分发:DSL 的 action 字符串统一交给 Router,带 scheme 白名单与埋点钩子。
public enum DSLAction {
    /// 允许路由的 scheme 白名单(防被污染的 schema 跳任意外链)。
    /// 由 PageSchemaManager.configure 同步,默认仅 wechat://。
    public static var allowedSchemes: Set<String> = ["wechat"]

    /// 埋点钩子(可选):上层可接入埋点系统。
    public static var tracker: ((String) -> Void)?

    public static func handle(_ raw: String?) {
        guard let raw, !raw.isEmpty, let url = URL(string: raw) else { return }
        guard let scheme = url.scheme, allowedSchemes.contains(scheme) else {
            print("[DSL] action scheme 不在白名单,拒绝路由: \(raw)")
            return
        }
        tracker?(raw)
        Router.shared.push(raw)
    }
}
