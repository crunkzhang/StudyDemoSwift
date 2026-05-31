import Foundation

/// 组件注册表:声明 DSLKit 当前能渲染哪些 type。
/// 渲染器遇到未注册的 type 直接跳过 → 老客户端不崩(新组件灰度上线的前提)。
public final class DSLComponentRegistry {
    public static let shared = DSLComponentRegistry()

    private var known: Set<String> = [
        "profileHeader", "group", "cell", "spacer",      // 列表型
        "banner", "grid", "gridItem", "text",            // 楼层型
        "card"                                            // IM 卡片消息
    ]

    private init() {}

    public func isKnown(_ type: String) -> Bool { known.contains(type) }
    public func register(_ type: String) { known.insert(type) }
}
