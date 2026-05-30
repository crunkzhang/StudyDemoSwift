import Foundation

/// 有草稿的会话优先(微信交互:输入框打字未发,会话排到上面)
public struct DraftSortRule: SortRule {
    public init() {}

    public func compare(_ lhs: SessionCellModel, _ rhs: SessionCellModel) -> ComparisonResult {
        let lHas = !(lhs.draft?.isEmpty ?? true)
        let rHas = !(rhs.draft?.isEmpty ?? true)
        if lHas == rHas { return .orderedSame }
        return lHas ? .orderedAscending : .orderedDescending
    }
}
