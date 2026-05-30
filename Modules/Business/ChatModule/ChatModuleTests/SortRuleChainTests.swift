import XCTest
@testable import ChatModule

final class SortRuleChainTests: XCTestCase {

    /// 测试规则:按 unread 倒序(高在前)
    private struct UnreadRule: SortRule {
        func compare(_ l: SessionCellModel, _ r: SessionCellModel) -> ComparisonResult {
            if l.unreadCount == r.unreadCount { return .orderedSame }
            return l.unreadCount > r.unreadCount ? .orderedAscending : .orderedDescending
        }
    }

    private struct AlphaRule: SortRule {
        func compare(_ l: SessionCellModel, _ r: SessionCellModel) -> ComparisonResult {
            (l.contactName as NSString).compare(r.contactName)
        }
    }

    private func m(_ id: String, name: String = "x", unread: Int = 0) -> SessionCellModel {
        SessionCellModel(sessionId: id, contactName: name, avatarURL: nil,
                         avatarInitial: String(name.prefix(1)), avatarColor: 0x07C160,
                         lastMsgPreview: "", formattedTime: "",
                         unreadCount: unread, isPinned: false, lastTimestamp: 0)
    }

    func test_singleRule_sortsCorrectly() {
        let chain = SortRuleChain(rules: [UnreadRule()])
        let r = chain.sort([m("a", unread: 1), m("b", unread: 5), m("c", unread: 3)])
        XCTAssertEqual(r.map(\.sessionId), ["b", "c", "a"])
    }

    func test_chainFallsThrough_whenFirstRuleSame() {
        let chain = SortRuleChain(rules: [UnreadRule(), AlphaRule()])
        let r = chain.sort([m("1", name: "C"), m("2", name: "A"), m("3", name: "B")])
        XCTAssertEqual(r.map(\.contactName), ["A", "B", "C"])
    }

    func test_chainStops_whenFirstRuleResolves() {
        let chain = SortRuleChain(rules: [UnreadRule(), AlphaRule()])
        let r = chain.sort([m("1", name: "Z", unread: 1), m("2", name: "A", unread: 5)])
        XCTAssertEqual(r.map(\.sessionId), ["2", "1"])
    }
}
