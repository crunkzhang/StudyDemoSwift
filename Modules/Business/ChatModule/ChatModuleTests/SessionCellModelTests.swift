import XCTest
@testable import ChatModule

final class SessionCellModelTests: XCTestCase {

    private func make(sessionId: String = "s1", name: String = "张三",
                      unread: Int = 0, pinned: Bool = false,
                      ts: Int64 = 100) -> SessionCellModel {
        SessionCellModel(
            sessionId: sessionId, contactName: name, avatarURL: nil,
            avatarInitial: String(name.prefix(1)), avatarColor: 0x07C160,
            lastMsgPreview: "hi", formattedTime: "12:00",
            unreadCount: unread, isPinned: pinned, lastTimestamp: ts
        )
    }

    func test_hash_stableForSameSessionId() {
        XCTAssertEqual(make(sessionId: "s1", name: "A").hashValue,
                       make(sessionId: "s1", name: "B").hashValue)
    }

    func test_equality_comparesAllFields() {
        XCTAssertEqual(make(unread: 5), make(unread: 5))
    }

    func test_inequality_whenUnreadChanges() {
        XCTAssertNotEqual(make(unread: 0), make(unread: 1))
    }
}
