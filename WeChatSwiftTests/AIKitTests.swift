import XCTest
import AIKit

final class AIKitModelsTests: XCTestCase {
    func test_request_defaults() {
        let req = AIRequest(system: "s", messages: [AIMessage(role: .user, content: "hi")])
        XCTAssertEqual(req.maxTokens, 256)
        XCTAssertEqual(req.temperature, 0.2, accuracy: 0.0001)
        XCTAssertEqual(req.messages.first?.role, .user)
    }
}
