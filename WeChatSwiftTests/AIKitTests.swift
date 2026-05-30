import XCTest
@testable import AIKit

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

final class ClaudeProviderTests: XCTestCase {
    let provider = ClaudeProvider(baseURL: URL(string: "https://api.anthropic.com")!,
                                  apiKey: "sk-test", model: "claude-opus-4-8")

    func test_makeRequest_setsHeadersAndBody() throws {
        let req = AIRequest(system: "你是裁判",
                            messages: [AIMessage(role: .user, content: "他死了吗?")],
                            maxTokens: 128, temperature: 0.2)
        let urlReq = try provider.makeURLRequest(req)
        XCTAssertEqual(urlReq.url?.absoluteString, "https://api.anthropic.com/v1/messages")
        XCTAssertEqual(urlReq.httpMethod, "POST")
        XCTAssertEqual(urlReq.value(forHTTPHeaderField: "x-api-key"), "sk-test")
        XCTAssertEqual(urlReq.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")
        let body = try JSONSerialization.jsonObject(with: urlReq.httpBody ?? Data()) as! [String: Any]
        XCTAssertEqual(body["model"] as? String, "claude-opus-4-8")
        XCTAssertEqual(body["max_tokens"] as? Int, 128)
        XCTAssertEqual(body["system"] as? String, "你是裁判")
        let msgs = body["messages"] as! [[String: Any]]
        XCTAssertEqual(msgs.first?["role"] as? String, "user")
        XCTAssertEqual(msgs.first?["content"] as? String, "他死了吗?")
    }

    func test_parse_joinsTextBlocks() throws {
        let json = """
        {"content":[{"type":"text","text":"是。"},{"type":"text","text":"接近真相了"}]}
        """.data(using: .utf8)!
        let resp = try provider.parse(json)
        XCTAssertEqual(resp.text, "是。接近真相了")
    }
}
