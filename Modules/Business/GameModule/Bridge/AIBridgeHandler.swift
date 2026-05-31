import Foundation

public final class AIBridgeHandler: GameBridgeHandler, GameBridgeStreamHandler {
    public let namespace = "ai"
    private let service: HaiguitangService

    public init(service: HaiguitangService = HaiguitangService()) {
        self.service = service
    }

    public func handleStream(method: String, params: [String: Any],
                             emit: @escaping (String) -> Void) async -> BridgeResult {
        switch method {
        case "ai.startPuzzleStream":
            do {
                let r = try await service.startPuzzleStream(
                    difficulty: params["difficulty"] as? String ?? "normal",
                    theme: params["theme"] as? String,
                    avoid: params["avoid"] as? [String] ?? [],
                    onDelta: emit)
                return .success(["puzzleId": r.puzzleId, "title": r.title, "surface": r.surface])
            } catch {
                return .failure(code: "AI_ERROR", message: "\(error)")
            }
        default:
            return await handle(method: method, params: params)
        }
    }

    public func handle(method: String, params: [String: Any]) async -> BridgeResult {
        do {
            switch method {
            case "ai.startPuzzle":
                let r = try await service.startPuzzle(
                    difficulty: params["difficulty"] as? String ?? "normal",
                    theme: params["theme"] as? String,
                    avoid: params["avoid"] as? [String] ?? [])
                return .success(["puzzleId": r.puzzleId, "title": r.title, "surface": r.surface])

            case "ai.ask":
                guard let id = params["puzzleId"] as? String,
                      let q = params["question"] as? String else {
                    return .failure(code: "BAD_PARAMS", message: "缺少 puzzleId/question")
                }
                let r = try await service.ask(puzzleId: id, question: q)
                return .success(["verdict": r.verdict.rawValue, "comment": r.comment, "solved": r.solved])

            case "ai.guess":
                guard let id = params["puzzleId"] as? String,
                      let g = params["guess"] as? String else {
                    return .failure(code: "BAD_PARAMS", message: "缺少 puzzleId/guess")
                }
                let r = try await service.guess(puzzleId: id, guess: g)
                var data: [String: Any] = ["solved": r.solved, "comment": r.comment]
                if let sol = r.solution { data["solution"] = sol }
                return .success(data)

            case "ai.hint":
                guard let id = params["puzzleId"] as? String else {
                    return .failure(code: "BAD_PARAMS", message: "缺少 puzzleId")
                }
                let r = try await service.hint(puzzleId: id)
                return .success(["hint": r.hint])

            case "ai.giveUp":
                guard let id = params["puzzleId"] as? String else {
                    return .failure(code: "BAD_PARAMS", message: "缺少 puzzleId")
                }
                let r = try await service.giveUp(puzzleId: id)
                return .success(["solution": r.solution])

            default:
                return .failure(code: "UNKNOWN_METHOD", message: method)
            }
        } catch {
            return .failure(code: "AI_ERROR", message: "\(error)")
        }
    }
}
