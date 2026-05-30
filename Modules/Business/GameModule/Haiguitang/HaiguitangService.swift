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

    func startPuzzle(difficulty: String, theme: String?) async throws -> StartResult {
        let req = AIRequest(
            system: HaiguitangPrompts.generateSystem,
            messages: [AIMessage(role: .user, content: HaiguitangPrompts.generateUser(difficulty: difficulty, theme: theme))],
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
