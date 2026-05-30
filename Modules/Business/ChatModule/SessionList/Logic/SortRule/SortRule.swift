import Foundation

public protocol SortRule {
    /// .orderedSame 时让出给链表下一个规则
    func compare(_ lhs: SessionCellModel, _ rhs: SessionCellModel) -> ComparisonResult
}

/// 链表式可插拔排序 — 规则数组顺序 = 优先级。
/// 新增规则只加 SortRule 子类,不动既有代码(开闭原则)。
public final class SortRuleChain {
    private let rules: [SortRule]

    public init(rules: [SortRule]) {
        self.rules = rules
    }

    public func sort(_ sessions: [SessionCellModel]) -> [SessionCellModel] {
        sessions.sorted { lhs, rhs in
            for rule in rules {
                switch rule.compare(lhs, rhs) {
                case .orderedAscending:  return true
                case .orderedDescending: return false
                case .orderedSame:       continue
                }
            }
            return false
        }
    }
}
