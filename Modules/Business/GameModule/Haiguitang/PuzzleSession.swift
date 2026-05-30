import Foundation

public enum Verdict: String {
    case yes, no, irrelevant, partial, close
}

struct PuzzleSession {
    let puzzleId: String
    let title: String
    let surface: String          // 汤面(可下发)
    let solution: String         // 汤底(机密,绝不下发,除非 solved/giveUp)
    var history: [(question: String, verdict: Verdict)]
    var solved: Bool
    let difficulty: String
    let theme: String?
}

// 各动作返回(供 AIBridgeHandler 打包成 JSON)
struct StartResult { let puzzleId: String; let title: String; let surface: String }
struct AskResult   { let verdict: Verdict; let comment: String; let solved: Bool }
struct GuessResult { let solved: Bool; let comment: String; let solution: String? }
struct HintResult  { let hint: String }
struct GiveUpResult { let solution: String }
