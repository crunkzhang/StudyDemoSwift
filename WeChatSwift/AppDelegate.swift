import UIKit
import WeChatRN
import CatonMonitorKit
import WCIMSDK
import ChatModule
import GameModule
import AIKit
import DSLKit

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

        // 动态化页面(SDUI):路由注册 + 后台拉取 page schema(「我的」页 / 活动页等)
        DSLKit.registerRoutes()
        PageSchemaManager.shared.start(
            remoteURL: "https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com/pages/manifest.json"
        )

        // AI 能力(海龟汤等):多厂商 OpenAI 兼容,游戏内可切换;key 走 Keychain
        // ⚠️ 临时:首次把三家 key 写进 Keychain,跑一次后删除这三行(勿提交)
        KeychainAIKey.save("sk-b35394db582c45be939e87aedeb0c494", vendor: "deepseek")
        KeychainAIKey.save("sk-697d00cd8da64998902daa643ecaef24", vendor: "qwen")
        KeychainAIKey.save("54b77dcf832e4ed9a37646357ee2e56f.e7j0089vMjJpIWW6", vendor: "zhipu")
        AIConfig.installSelected()

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
}
