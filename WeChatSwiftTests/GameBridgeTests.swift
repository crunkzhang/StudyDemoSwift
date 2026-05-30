import XCTest
import AIKit
@testable import GameModule

final class GameBridgeTests: XCTestCase {

    private func handler(_ texts: [String]) -> AIBridgeHandler {
        let box = Box(texts)
        let client = AIClient(provider: MockProvider { _ in .success(AIResponse(text: box.next())) })
        return AIBridgeHandler(service: HaiguitangService(client: client))
    }

    func test_startPuzzle_returnsSurfaceNotSolution() async {
        let h = handler([#"{"title":"T","surface":"汤面X","solution":"汤底Y"}"#])
        let result = await h.handle(method: "ai.startPuzzle", params: ["difficulty": "normal"])
        guard case .success(let data) = result else { return XCTFail("应成功") }
        XCTAssertEqual(data["surface"] as? String, "汤面X")
        XCTAssertNotNil(data["puzzleId"])
        XCTAssertNil(data["solution"])           // 绝不下发汤底
    }

    func test_unknownMethod_returnsFailure() async {
        let h = handler(["{}"])
        let result = await h.handle(method: "ai.unknown", params: [:])
        guard case .failure(let code, _) = result else { return XCTFail("应失败") }
        XCTAssertEqual(code, "UNKNOWN_METHOD")
    }

    func test_bridge_dispatchesToRegisteredHandler() async {
        let h = handler([#"{"title":"T","surface":"汤面X","solution":"Y"}"#])
        let bridge = GameBridge()
        bridge.register(handler: h)
        let result = await bridge.resolve(method: "ai.startPuzzle", params: ["difficulty": "normal"])
        guard case .success(let data) = result else { return XCTFail() }
        XCTAssertEqual(data["surface"] as? String, "汤面X")
    }

    func test_bridge_noHandler_returnsFailure() async {
        let bridge = GameBridge()
        let result = await bridge.resolve(method: "im.share", params: [:])
        guard case .failure(let code, _) = result else { return XCTFail() }
        XCTAssertEqual(code, "NO_HANDLER")
    }
}
