import Foundation

public final class AIBridgeHandler: GameBridgeHandler {
    public let namespace = "ai"
    private let service: HaiguitangService

    public init(service: HaiguitangService = HaiguitangService()) {
        self.service = service
    }

    public func handle(method: String, params: [String: Any]) async -> BridgeResult {
        do {
            switch method {
            case "ai.startPuzzle":
                let r = try await service.startPuzzle(
                    difficulty: params["difficulty"] as? String ?? "normal",
                    theme: params["theme"] as? String)
                return .success(["puzzleId": r.puzzleId, "title": r.title, "surface": r.surface])

            case "ai.ask":
                guard let id = params["puzzleId"] as? String,
                      let q = params["question"] as? String else {
                    return .failure(code: "BAD_PARAMS", message: "缺少 puzzleId/question")
                }
                let r = try await service.ask(puzzleId: id, question: q)
                return .success(["verdict": r.verdict.rawValue, "comment": r.comment, "solved": r.solved])

            default:
                return .failure(code: "UNKNOWN_METHOD", message: method)
            }
        } catch {
            return .failure(code: "AI_ERROR", message: "\(error)")
        }
    }
}
