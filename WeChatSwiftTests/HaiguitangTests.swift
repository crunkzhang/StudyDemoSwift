import XCTest
import AIKit
@testable import GameModule

// 测试用:线程安全顺序取值(被多个海龟汤测试共用)
final class Box {
    private var items: [String]; private let lock = NSLock()
    init(_ items: [String]) { self.items = items }
    func next() -> String { lock.lock(); defer { lock.unlock() }
        return items.isEmpty ? "{}" : items.removeFirst() }
}

final class HaiguitangServiceTests: XCTestCase {

    private func service(_ text: String) -> HaiguitangService {
        let client = AIClient(provider: MockProvider { _ in .success(AIResponse(text: text)) })
        return HaiguitangService(client: client)
    }

    // 顺序返回多段文本的 service:第1段给 startPuzzle,后续给 ask/guess/hint
    private func sequencedService(_ texts: [String]) -> HaiguitangService {
        let box = Box(texts)
        let client = AIClient(provider: MockProvider { _ in .success(AIResponse(text: box.next())) })
        return HaiguitangService(client: client)
    }

    func test_startPuzzle_buildsSessionAndHidesSolution() async throws {
        let svc = service(#"{"title":"海龟汤","surface":"他喝了汤就自杀了","solution":"那不是海龟汤"}"#)
        let r = try await svc.startPuzzle(difficulty: "normal", theme: nil)
        XCTAssertEqual(r.title, "海龟汤")
        XCTAssertEqual(r.surface, "他喝了汤就自杀了")
        XCTAssertFalse(r.puzzleId.isEmpty)
        // 汤底不在返回里(StartResult 无 solution 字段),但 session 应已存
        let sol = await svc.debugSolution(for: r.puzzleId)
        XCTAssertEqual(sol, "那不是海龟汤")
    }
}
