import Foundation

public struct PinnedSortRule: SortRule {
    public init() {}

    public func compare(_ lhs: SessionCellModel, _ rhs: SessionCellModel) -> ComparisonResult {
        if lhs.isPinned == rhs.isPinned { return .orderedSame }
        return lhs.isPinned ? .orderedAscending : .orderedDescending
    }
}
