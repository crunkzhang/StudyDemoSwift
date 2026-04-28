import UIKit
import WeChatRN
import ChatModule
import ContactModule
import DiscoverModule
import MeModule

class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        LaunchMetrics.mark("didFinishStart")

        // ── 原有 RN 初始化 ──
        RNFactoryManager.shared.setup()
        RNBundleManager.shared.configure(
            remoteURL: "https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com",
            appVersion: "1.0.0"
        )
        RNBundleManager.shared.start()

        // ── SDK 并行调度 ──
        LaunchScheduler.shared.registerAll()
        LaunchScheduler.shared.start()

        // ── 路由注册 ──
        RNBaseViewController.registerPageRoute()
        ChatModule.registerRoutes()
        ContactModule.registerRoutes()
        DiscoverModule.registerRoutes()
        MeModule.registerRoutes()

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
