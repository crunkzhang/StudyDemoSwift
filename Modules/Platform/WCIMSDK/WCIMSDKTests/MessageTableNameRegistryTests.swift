import XCTest
@testable import WCIMSDK

final class MessageTableNameRegistryTests: XCTestCase {
    var registry: MessageTableNameRegistry!

    override func setUp() {
        super.setUp()
        registry = MessageTableNameRegistry()
    }

    func test_tableName_isDeterministic() {
        XCTAssertEqual(registry.tableName(for: "u123-u456"),
                       registry.tableName(for: "u123-u456"))
    }

    func test_tableName_hasMessagePrefix() {
        XCTAssertTrue(registry.tableName(for: "u123-u456").hasPrefix("message_"))
    }

    func test_tableName_isFixedLength_24chars() {
        XCTAssertEqual(registry.tableName(for: "u123-u456").count, 24)
    }

    func test_tableName_onlyAllowsSafeChars() {
        let name = registry.tableName(for: "u'; DROP TABLE; --")
        let safe = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        XCTAssertNil(name.rangeOfCharacter(from: safe.inverted))
    }

    func test_differentSessions_produceDifferentNames() {
        XCTAssertNotEqual(registry.tableName(for: "u1-u2"),
                          registry.tableName(for: "u1-u3"))
    }
}
