import Foundation
import AIKit

public actor HaiguitangService {
    private let client: AIClient
    private var sessions: [String: PuzzleSession] = [:]

    public init(client: AIClient = .shared) { self.client = client }

    // 测试辅助:读某局汤底 / 历史
    func debugSolution(for id: String) -> String? { sessions[id]?.solution }
    func debugHistoryCount(for id: String) -> Int { sessions[id]?.history.count ?? 0 }

    // MARK: - 生成

    func startPuzzle(difficulty: String, theme: String?, avoid: [String] = []) async throws -> StartResult {
        let req = AIRequest(
            system: HaiguitangPrompts.generateSystem,
            messages: [AIMessage(role: .user, content: HaiguitangPrompts.generateUser(difficulty: difficulty, theme: theme, avoid: avoid))],
            maxTokens: 512, temperature: 0.8
        )
        let resp = try await client.complete(req)
        guard let obj = Self.extractJSON(resp.text),
              let title = obj["title"] as? String,
              let surface = obj["surface"] as? String,
              let solution = obj["solution"] as? String else {
            throw AIError.decoding
        }
        let id = UUID().uuidString
        sessions[id] = PuzzleSession(puzzleId: id, title: title, surface: surface,
                                     solution: solution, history: [], solved: false,
                                     difficulty: difficulty, theme: theme)
        return StartResult(puzzleId: id, title: title, surface: surface)
    }

    // MARK: - 流式出题(两段式:汤底非流式 + 汤面流式)

    func startPuzzleStream(difficulty: String, theme: String?, avoid: [String],
                           onDelta: @escaping (String) -> Void) async throws -> StartResult {
        // ① 生成汤底 + 标题(非流式,汤底留原生)
        let truthReq = AIRequest(
            system: HaiguitangPrompts.truthSystem,
            messages: [AIMessage(role: .user, content: HaiguitangPrompts.truthUser(difficulty: difficulty, theme: theme, avoid: avoid))],
            maxTokens: 400, temperature: 0.85
        )
        let tResp = try await client.complete(truthReq)
        guard let obj = Self.extractJSON(tResp.text),
              let title = obj["title"] as? String,
              let solution = obj["solution"] as? String else {
            throw AIError.decoding
        }

        // ② 流式生成汤面(纯文本,逐段回调)
        let surfaceReq = AIRequest(
            system: HaiguitangPrompts.surfaceStreamSystem,
            messages: [AIMessage(role: .user, content: HaiguitangPrompts.surfaceStreamUser(solution: solution))],
            maxTokens: 300, temperature: 0.9
        )
        var surface = ""
        for try await chunk in client.completeStream(surfaceReq) {
            surface += chunk
            onDelta(chunk)
        }
        surface = surface.trimmingCharacters(in: .whitespacesAndNewlines)
        if surface.isEmpty { throw AIError.decoding }

        let id = UUID().uuidString
        sessions[id] = PuzzleSession(puzzleId: id, title: title, surface: surface,
                                     solution: solution, history: [], solved: false,
                                     difficulty: difficulty, theme: theme)
        return StartResult(puzzleId: id, title: title, surface: surface)
    }

    // MARK: - 裁判

    func ask(puzzleId: String, question: String) async throws -> AskResult {
        guard var session = sessions[puzzleId] else { throw AIError.provider(message: "puzzle not found") }
        let ctx = HaiguitangPrompts.contextBlock(surface: session.surface,
                                                 solution: session.solution, history: session.history)
        let user = ctx + "\n【玩家本次提问】\n\(question)"
        let req = AIRequest(system: HaiguitangPrompts.judgeSystem,
                            messages: [AIMessage(role: .user, content: user)],
                            maxTokens: 128, temperature: 0.2)

        let parsed = await completeJSONWithRetry(req)
        let verdict = (parsed?["verdict"] as? String).flatMap(Verdict.init(rawValue:)) ?? .irrelevant
        let comment = (parsed?["comment"] as? String) ?? "我没太懂,换个问法?"
        let solved = (parsed?["solved"] as? Bool) ?? false

        session.history.append((question: question, verdict: verdict))
        if solved { session.solved = true }
        sessions[puzzleId] = session
        return AskResult(verdict: verdict, comment: comment, solved: solved)
    }

    func guess(puzzleId: String, guess: String) async throws -> GuessResult {
        guard var session = sessions[puzzleId] else { throw AIError.provider(message: "not found") }
        let ctx = HaiguitangPrompts.contextBlock(surface: session.surface,
                                                 solution: session.solution, history: session.history)
        let user = ctx + "\n【玩家提交的还原】\n\(guess)"
        let req = AIRequest(system: HaiguitangPrompts.guessSystem,
                            messages: [AIMessage(role: .user, content: user)],
                            maxTokens: 128, temperature: 0.2)
        let parsed = await completeJSONWithRetry(req)
        let solved = (parsed?["solved"] as? Bool) ?? false
        let comment = (parsed?["comment"] as? String) ?? "还差点意思,再想想~"
        if solved { session.solved = true; sessions[puzzleId] = session }
        return GuessResult(solved: solved, comment: comment, solution: solved ? session.solution : nil)
    }

    func hint(puzzleId: String) async throws -> HintResult {
        guard let session = sessions[puzzleId] else { throw AIError.provider(message: "not found") }
        let ctx = HaiguitangPrompts.contextBlock(surface: session.surface,
                                                 solution: session.solution, history: session.history)
        let req = AIRequest(system: HaiguitangPrompts.hintSystem,
                            messages: [AIMessage(role: .user, content: ctx)],
                            maxTokens: 64, temperature: 0.5)
        let parsed = await completeJSONWithRetry(req)
        return HintResult(hint: (parsed?["hint"] as? String) ?? "再多问几个问题缩小范围吧")
    }

    func giveUp(puzzleId: String) throws -> GiveUpResult {
        guard let session = sessions[puzzleId] else { throw AIError.provider(message: "not found") }
        return GiveUpResult(solution: session.solution)
    }

    /// 调一次,解析失败再重试一次;最终仍失败返回 nil(由调用方走安全降级默认值)。
    private func completeJSONWithRetry(_ req: AIRequest) async -> [String: Any]? {
        for _ in 0..<2 {
            if let resp = try? await client.complete(req),
               let obj = Self.extractJSON(resp.text) {
                return obj
            }
        }
        return nil
    }

    // MARK: - JSON 守卫

    /// 直接解析失败时,抽取首个 {...} 子串再试。返回顶层字典或 nil。
    static func extractJSON(_ text: String) -> [String: Any]? {
        if let d = text.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
            return obj
        }
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"), start < end else { return nil }
        let sub = String(text[start...end])
        guard let d = sub.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
        return obj
    }
}
