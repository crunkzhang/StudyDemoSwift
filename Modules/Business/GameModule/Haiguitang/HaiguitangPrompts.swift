import Foundation

enum HaiguitangPrompts {

    // 说明:对模型一律用「谜面/谜底」而非「汤面/汤底」,避免被字面理解成食物(汤、面条)。

    /// 难度 → 明确的出题约束,让三档体感真正不同
    private static func difficultyGuide(_ difficulty: String) -> String {
        switch difficulty {
        case "easy":
            return "难度【简单】:线索明显,真相只需一层推理,适合新手。"
        case "hard":
            return "难度【困难】:带强误导,真相需多层反转、出人意料但仍逻辑自洽。"
        default:
            return "难度【普通】:需要 2-3 步推理,可有适度误导。"
        }
    }

    // ── 单次(非流式)出题,保留兼容 ──

    static let generateSystem = """
    你是「海龟汤」情景推理谜题的出题人。注意:「海龟汤」只是这类侦探推理游戏的名字,
    题目内容与汤、食物无关,不要出关于做饭/面条/汤的题。
    一道好题 = 一个【具体的、反常的事件(通常和人有关)】+ 一个【出人意料但完全逻辑自洽的真相】。
    只输出 JSON:{"title":"≤10字标题","surface":"2-4句谜面:描述那个反常事件,只给现象不给原因,结尾点明要解开的疑问(如'这是为什么?')","solution":"完整真相,能解释谜面里的一切疑点"}
    范例:{"title":"画中线索","surface":"一场普通的画作拍卖会上,一位警察盯着一幅画突然脸色大变,冲出会场。三小时后,一个失踪三个月的人获救了。这是为什么?","solution":"画家被绑架后被迫作画,他在画里悄悄画进了关押他的房间和绑匪样貌;画流入拍卖会,警察认出细节顺藤摸瓜救出了他。"}
    """

    static func generateUser(difficulty: String, theme: String?, avoid: [String]) -> String {
        var s = difficultyGuide(difficulty)
        if let t = theme, !t.isEmpty { s += "\n题目风格:【\(t)】,谜面与真相都要贴合该风格氛围。" }
        if !avoid.isEmpty { s += "\n请避免与这些已出过的题重复:\(avoid.joined(separator: "、"))。" }
        s += "\n请出一道全新的题。"
        return s
    }

    // ── 流式出题:两段式(先生成真相,再流式生成谜面)──

    static let truthSystem = """
    你是「海龟汤」情景推理谜题的出题人。注意:「海龟汤」只是这类侦探推理游戏的名字,
    题目与汤、食物无关,绝不要出关于做饭/面条/汤的题。
    请构思一个【具体的反常事件 + 出人意料但逻辑自洽的真相】,真相要能被是非提问逐步还原。
    只输出 JSON:{"title":"≤10字标题","solution":"完整真相,清楚交代:谁、做了什么、为什么这么反常"}
    范例:{"title":"画中线索","solution":"画家被绑架后被迫作画,在画里悄悄画进关押他的房间和绑匪样貌;画流入拍卖会,一名警察认出细节,顺藤摸瓜救出了他。"}
    """

    static func truthUser(difficulty: String, theme: String?, avoid: [String]) -> String {
        var s = difficultyGuide(difficulty)
        if let t = theme, !t.isEmpty { s += "\n题目风格:【\(t)】,真相要贴合该风格。" }
        if !avoid.isEmpty { s += "\n请避免与这些已出过的题重复:\(avoid.joined(separator: "、"))。" }
        s += "\n请构思一个全新的真相。"
        return s
    }

    static let surfaceStreamSystem = """
    你是「海龟汤」推理谜题的出题人。下面给你一道题的【真相】。请据此写出对应的【谜面】:
    - 2-4 句,描述真相里那个【反常的事件/现象】,只给表面、不给原因;
    - 绝对不能剧透真相或任何关键因果;
    - 结尾必须点明玩家要解开的疑问(如"这是为什么?"或"请还原事情的经过")。
    直接输出谜面文本,不要 JSON、不要任何前后缀或解释。
    范例(对应"画中线索"):一场普通的画作拍卖会上,一位警察盯着一幅画突然脸色大变,冲出会场。三小时后,一个失踪三个月的人获救了。这是为什么?
    """

    static func surfaceStreamUser(solution: String) -> String {
        "【真相(仅你可见,严禁泄露)】\n\(solution)\n\n请写出谜面。"
    }

    // ── 裁判 ──

    static let judgeSystem = """
    你是「海龟汤」推理游戏的裁判。我会给你【谜面】【真相(仅你可见,严禁泄露)】和提问历史。
    针对玩家【本次是非提问】,只依据真相判定,输出 JSON,不要多余文字:
    {"verdict":"yes|no|irrelevant|partial|close","comment":"≤15字、不得泄露真相关键信息","solved":false}
    含义:yes=是 / no=不是 / irrelevant=与真相无关 / partial=部分正确 / close=已非常接近真相。
    solved 恒为 false(是否通关由"解答"判定)。
    """

    static let guessSystem = """
    你是「海龟汤」裁判。玩家提交了他对真相的"还原"。请对照【真相】判断他是否抓住了核心
    (细节不必完全一致,关键因果对上即可)。只输出 JSON:{"solved":true/false,"comment":"≤20字点评,不剧透"}
    """

    static let hintSystem = """
    你是「海龟汤」裁判。请基于【真相】给玩家一条不直接说破的提示,引导其往关键方向想。
    只输出 JSON:{"hint":"≤25字提示"}
    """

    /// 把谜面 + 真相 + 历史拼成判定用的 user 文本
    static func contextBlock(surface: String, solution: String,
                             history: [(question: String, verdict: Verdict)]) -> String {
        var s = "【谜面】\n\(surface)\n\n【真相】\n\(solution)\n"
        if !history.isEmpty {
            s += "\n【已问历史】\n"
            for (i, h) in history.enumerated() {
                s += "\(i + 1). 问:\(h.question) 答:\(h.verdict.rawValue)\n"
            }
        }
        return s
    }
}
