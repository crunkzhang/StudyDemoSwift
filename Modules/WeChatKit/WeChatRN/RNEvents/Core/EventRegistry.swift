import Foundation

/// 全局事件清单聚合入口 —— 所有业务模块事件在这里汇总，
/// 供 EventBridge.supportedEvents 使用。
enum EventRegistry {
    static let all: [String] = NavbarEvents.all
}
