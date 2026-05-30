import UIKit
import WeChatRN
import CatonMonitorKit
import WCIMSDK
import ChatModule
import GameModule
import AIKit

class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        LaunchMetrics.mark("didFinishStart")

        // IM SDK 初始化(写死 mock 本地用户 ID),并异步触发首次同步
        WCIMSDK.setup(userId: "mock_local_user")
        Task { await WCIMSDK.syncCoordinator?.triggerSync() }

        // 主线程强依赖：CADisplayLink + method swizzle 不能放后台线程
        CatonMonitor.shared.start()
        // 主线程强依赖：RCTReactNativeFactory init 需主线程
        RNFactoryManager.shared.setup()

        // 原生路由注册(IM 详情页改为原生)
        ChatModule.registerRoutes()

        // 游戏中心：路由注册 + manifest 后台拉取(30min 轮询)
        GameModule.registerRoutes()
        GameBundleManager.shared.start(
            remoteURL: "https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com/games/manifest.json"
        )

        // AI 能力(海龟汤等)provider 装配
        // DEBUG:内置 Mock,离线即可玩一局(演示用);要真生成切回 .claudeProxy/.claudeDirect
        // RELEASE:直连 Anthropic,key 走 Keychain
        #if DEBUG
        AIConfig.install(.mock(MockProvider { req in Self.haiguitangMock(req) }))
        // 真生成时改回:AIConfig.install(.claudeProxy(baseURL: URL(string: "http://localhost:8787")!))
        #else
        AIConfig.install(.claudeDirect(apiKey: KeychainAIKey.load() ?? ""))
        #endif

        // 路由注册（syncAtStart）+ RN Bundle 热更新（afterFirstFrame）已移入调度器
        LaunchScheduler.shared.registerAll()
        LaunchScheduler.shared.start()

        LaunchMetrics.mark("didFinishEnd")
        LaunchMetrics.observeFirstFrame()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
    }

    #if DEBUG
    /// 海龟汤离线 Mock:出固定汤面 + 按关键词判定,答对揭晓汤底。仅供演示。
    private static func haiguitangMock(_ req: AIRequest) -> Result<AIResponse, AIError> {
        func resp(_ obj: [String: Any]) -> Result<AIResponse, AIError> {
            let data = (try? JSONSerialization.data(withJSONObject: obj)) ?? Data("{}".utf8)
            return .success(AIResponse(text: String(data: data, encoding: .utf8) ?? "{}"))
        }
        let sys = req.system
        let user = req.messages.last?.content ?? ""

        // 出题
        if sys.contains("出题人") {
            return resp([
                "title": "海龟汤",
                "surface": "一个男人在餐厅点了一碗海龟汤,喝了一口后,回到家就自杀了。",
                "solution": "他曾在海难中漂流求生,同伴说喂他喝的是『海龟汤』,实际上是用遇难同伴的人肉熬的汤骗他活下来。这次他在餐厅喝到真正的海龟汤,发现味道和当年完全不同,才惊觉当年喝下的是人肉,无法承受真相而自杀。"
            ])
        }
        // 提示
        if sys.contains("提示") {
            return resp(["hint": "想想他『以前』是不是也喝过别人口中的『海龟汤』。"])
        }
        // 解答判定
        if sys.contains("还原") {
            let g = user.components(separatedBy: "【玩家提交的还原】").last ?? user
            let solved = ["人肉", "海难", "同伴", "尸体", "吃人"].contains { g.contains($0) }
            return resp(["solved": solved, "comment": solved ? "你抓住了核心真相!" : "关键因果还没对上,再想想"])
        }
        // 提问裁判(只看问题部分,避免命中带汤底的上下文)
        let q = user.components(separatedBy: "【玩家本次提问】").last ?? user
        let verdict: String
        if ["人肉", "吃人", "尸体"].contains(where: { q.contains($0) }) { verdict = "yes" }
        else if ["味道", "不同", "不一样", "真相", "以前", "之前", "当年"].contains(where: { q.contains($0) }) { verdict = "yes" }
        else if ["海难", "漂流", "船", "海上", "同伴", "朋友", "救"].contains(where: { q.contains($0) }) { verdict = "close" }
        else if ["毒", "凶手", "谋杀", "他杀", "仇"].contains(where: { q.contains($0) }) { verdict = "no" }
        else if ["天气", "钱", "工作", "女朋友", "感情"].contains(where: { q.contains($0) }) { verdict = "irrelevant" }
        else { verdict = "no" }
        return resp(["verdict": verdict, "comment": "", "solved": false])
    }
    #endif
}
