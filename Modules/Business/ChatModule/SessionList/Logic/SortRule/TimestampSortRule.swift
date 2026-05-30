import Foundation

/// 兜底规则 — 按 lastTimestamp 倒序(最新的在最上面)。
public struct TimestampSortRule: SortRule {
    public init() {}

    public func compare(_ lhs: SessionCellModel, _ rhs: SessionCellModel) -> ComparisonResult {
        if lhs.lastTimestamp == rhs.lastTimestamp { return .orderedSame }
        return lhs.lastTimestamp > rhs.lastTimestamp ? .orderedAscending : .orderedDescending
    }
}
