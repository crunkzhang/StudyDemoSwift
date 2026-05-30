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

final class MockProviderTests: XCTestCase {
    func test_mock_returnsConfiguredText() async throws {
        let mock = MockProvider { req in
            .success(AIResponse(text: "echo:" + (req.messages.last?.content ?? "")))
        }
        let resp = try await mock.complete(AIRequest(system: "", messages: [AIMessage(role: .user, content: "ping")]))
        XCTAssertEqual(resp.text, "echo:ping")
    }

    func test_mock_throwsConfiguredError() async {
        let mock = MockProvider { _ in .failure(.rateLimited) }
        do {
            _ = try await mock.complete(AIRequest(system: "", messages: []))
            XCTFail("应抛错")
        } catch let e as AIError {
            XCTAssertEqual(e, .rateLimited)
        } catch { XCTFail("错误类型不对") }
    }
}
