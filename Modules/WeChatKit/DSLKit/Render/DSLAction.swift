import Foundation
import WeChatRouter

/// 动作分发:DSL 的 action 字符串(wechat://...)统一交给 Router。
public enum DSLAction {
    /// 埋点钩子(可选):上层可替换以接入埋点系统。
    public static var tracker: ((String) -> Void)?

    public static func handle(_ raw: String?) {
        guard let raw, !raw.isEmpty, URL(string: raw) != nil else { return }
        tracker?(raw)
        Router.shared.push(raw)
    }
}
