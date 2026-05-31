import Foundation

enum HaiguitangPrompts {

    static let generateSystem = """
    你是「海龟汤」情景推理游戏的出题人。海龟汤是一种猜谜:给玩家一段看似诡异、信息不全的「汤面」,
    隐藏一个能自洽解释一切的完整真相「汤底」。请生成一道**逻辑自洽、有唯一核心真相、可通过是非提问还原**的题目。
    只输出 JSON,不要任何多余文字,格式:
    {"title":"≤10字标题","surface":"2-4句汤面,只给现象不给原因","solution":"完整真相,解释汤面所有疑点"}
    """

    /// 难度 → 明确的出题约束,让三档体感真正不同
    private static func difficultyGuide(_ difficulty: String) -> String {
        switch difficulty {
        case "easy":
            return "难度【简单】:汤面信息较完整、线索明显,真相只需一层推理即可还原,适合新手。"
        case "hard":
            return "难度【困难】:汤面极简且带强误导,真相需要多层反转、出人意料但仍逻辑自洽,适合老手烧脑。"
        default:
            return "难度【普通】:汤面留有明显缺口,需要 2-3 步推理,可有适度误导。"
        }
    }

    static func generateUser(difficulty: String, theme: String?, avoid: [String]) -> String {
        var s = difficultyGuide(difficulty)
        if let t = theme, !t.isEmpty {
            s += "\n题目风格:【\(t)】,汤面与汤底都要贴合该风格的氛围。"
        }
        if !avoid.isEmpty {
            s += "\n请避免与以下已出过的题重复(主题/核心诡计都要不同):\(avoid.joined(separator: "、"))。"
        }
        s += "\n请出一道全新的题。"
        return s
    }

    // ── 流式出题:两段式(先生成汤底,再流式生成汤面)──

    static let truthSystem = """
    你是「海龟汤」出题人。请构思一道逻辑自洽、有唯一核心真相、可通过是非提问还原的题目。
    只输出 JSON,不要多余文字:{"title":"≤10字标题","solution":"完整真相,能解释一切疑点"}
    """

    static func truthUser(difficulty: String, theme: String?, avoid: [String]) -> String {
        var s = difficultyGuide(difficulty)
        if let t = theme, !t.isEmpty { s += "\n题目风格:【\(t)】,真相要贴合该风格。" }
        if !avoid.isEmpty { s += "\n请避免与这些已出过的题重复:\(avoid.joined(separator: "、"))。" }
        s += "\n请构思一个全新的真相。"
        return s
    }

    static let surfaceStreamSystem = """
    你是「海龟汤」出题人。下面给你一道题的【真相】。请据此写出对应的【汤面】:
    2-4 句、只描述表面的诡异现象、留下悬念、绝对不能剧透真相或任何关键因果。悬疑笔触。
    直接输出汤面文本,不要 JSON、不要任何前后缀或解释。
    """

    static func surfaceStreamUser(solution: String) -> String {
        "【真相(仅你可见,严禁泄露)】\n\(solution)\n\n请写出汤面。"
    }

    static let judgeSystem = """
    你是「海龟汤」游戏的裁判。我会给你【汤面】【汤底(真相,仅你可见,严禁泄露)】和玩家的提问历史。
    针对玩家**本次是非提问**,只依据汤底判定,输出 JSON,不要多余文字:
    {"verdict":"yes|no|irrelevant|partial|close","comment":"≤15字、不得泄露汤底关键信息","solved":false}
    含义:yes=是 / no=不是 / irrelevant=与真相无关 / partial=部分正确(是也不是) / close=已非常接近真相。
    solved 恒为 false(是否通关由"解答"判定)。
    """

    static let guessSystem = """
    你是「海龟汤」裁判。玩家提交了他对真相的"还原"。请对照【汤底】判断他是否**抓住了核心真相**
    (细节不必完全一致,关键因果对上即可)。只输出 JSON:
    {"solved":true/false,"comment":"≤20字点评,不剧透"}
    """

    static let hintSystem = """
    你是「海龟汤」裁判。请基于【汤底】给玩家一条**不直接说破**的提示,引导其往关键方向想。
    只输出 JSON:{"hint":"≤25字提示"}
    """

    /// 把汤面 + 汤底 + 历史拼成判定用的 user 文本
    static func contextBlock(surface: String, solution: String,
                             history: [(question: String, verdict: Verdict)]) -> String {
        var s = "【汤面】\n\(surface)\n\n【汤底】\n\(solution)\n"
        if !history.isEmpty {
            s += "\n【已问历史】\n"
            for (i, h) in history.enumerated() {
                s += "\(i + 1). 问:\(h.question) 答:\(h.verdict.rawValue)\n"
            }
        }
        return s
    }
}
