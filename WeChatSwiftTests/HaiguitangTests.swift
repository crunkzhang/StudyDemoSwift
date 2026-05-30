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

    func test_ask_parsesVerdict_andAppendsHistory() async throws {
        let svc = sequencedService([
            #"{"title":"T","surface":"S","solution":"真相"}"#,
            #"{"verdict":"yes","comment":"没错","solved":false}"#
        ])
        let start = try await svc.startPuzzle(difficulty: "normal", theme: nil)
        let ask = try await svc.ask(puzzleId: start.puzzleId, question: "他认识凶手吗?")
        XCTAssertEqual(ask.verdict, .yes)
        XCTAssertEqual(ask.comment, "没错")
        XCTAssertFalse(ask.solved)
        let count = await svc.debugHistoryCount(for: start.puzzleId)
        XCTAssertEqual(count, 1)
    }

    func test_ask_malformedJSON_fallsBackSafely() async throws {
        let svc = sequencedService([
            #"{"title":"T","surface":"S","solution":"真相"}"#,
            "嗯……这个嘛(模型抽风,非 JSON)"
        ])
        let start = try await svc.startPuzzle(difficulty: "normal", theme: nil)
        let ask = try await svc.ask(puzzleId: start.puzzleId, question: "?")
        XCTAssertEqual(ask.verdict, .irrelevant)   // 安全降级
        XCTAssertFalse(ask.comment.isEmpty)
    }

    func test_ask_unknownPuzzle_throws() async {
        let svc = service("{}")
        do { _ = try await svc.ask(puzzleId: "nope", question: "?"); XCTFail() }
        catch {}
    }

    func test_guess_solved_returnsSolution() async throws {
        let svc = sequencedService([
            #"{"title":"T","surface":"S","solution":"真相Z"}"#,
            #"{"solved":true,"comment":"答对了"}"#
        ])
        let start = try await svc.startPuzzle(difficulty: "normal", theme: nil)
        let g = try await svc.guess(puzzleId: start.puzzleId, guess: "我觉得是Z")
        XCTAssertTrue(g.solved)
        XCTAssertEqual(g.solution, "真相Z")     // 通关才下发汤底
    }

    func test_guess_notSolved_hidesSolution() async throws {
        let svc = sequencedService([
            #"{"title":"T","surface":"S","solution":"真相Z"}"#,
            #"{"solved":false,"comment":"还差点"}"#
        ])
        let start = try await svc.startPuzzle(difficulty: "normal", theme: nil)
        let g = try await svc.guess(puzzleId: start.puzzleId, guess: "瞎猜")
        XCTAssertFalse(g.solved)
        XCTAssertNil(g.solution)
    }

    func test_giveUp_returnsSolution() async throws {
        let svc = sequencedService([#"{"title":"T","surface":"S","solution":"真相Z"}"#])
        let start = try await svc.startPuzzle(difficulty: "normal", theme: nil)
        let r = try await svc.giveUp(puzzleId: start.puzzleId)
        XCTAssertEqual(r.solution, "真相Z")
    }

    func test_hint_returnsText() async throws {
        let svc = sequencedService([
            #"{"title":"T","surface":"S","solution":"真相Z"}"#,
            #"{"hint":"注意他的过去"}"#
        ])
        let start = try await svc.startPuzzle(difficulty: "normal", theme: nil)
        let h = try await svc.hint(puzzleId: start.puzzleId)
        XCTAssertEqual(h.hint, "注意他的过去")
    }
}
