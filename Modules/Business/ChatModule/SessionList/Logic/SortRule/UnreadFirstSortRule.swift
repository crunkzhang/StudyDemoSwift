import Foundation

/// 未读消息优先(部分业务方按需开关 — 默认链不开)
public struct UnreadFirstSortRule: SortRule {
    public init() {}

    public func compare(_ lhs: SessionCellModel, _ rhs: SessionCellModel) -> ComparisonResult {
        let lUnread = lhs.unreadCount > 0
        let rUnread = rhs.unreadCount > 0
        if lUnread == rUnread { return .orderedSame }
        return lUnread ? .orderedAscending : .orderedDescending
    }
}
