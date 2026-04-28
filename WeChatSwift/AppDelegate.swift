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

        // ── Mock SDK 初始化（全串行，后续任务编排优化） ──
        // 第一梯队：无依赖
        LaunchMetrics.trackSDK("CrashSDK")    { CrashSDK.setup() }
        LaunchMetrics.trackSDK("DeviceIDSDK") { DeviceIDSDK.setup() }
        LaunchMetrics.trackSDK("ConfigSDK")   { ConfigSDK.setup() }

        // 第二梯队：有依赖
        LaunchMetrics.trackSDK("AnalyticsSDK") { AnalyticsSDK.setup() }
        LaunchMetrics.trackSDK("PushSDK")      { PushSDK.setup() }
        LaunchMetrics.trackSDK("ABTestSDK")    { ABTestSDK.setup() }
        LaunchMetrics.trackSDK("ShareSDK")     { ShareSDK.setup() }

        // 第三梯队：可延后（当前仍串行，演示优化空间）
        LaunchMetrics.trackSDK("MapSDK")  { MapSDK.setup() }
        LaunchMetrics.trackSDK("AdSDK")   { AdSDK.setup() }
        LaunchMetrics.trackSDK("PaySDK")  { PaySDK.setup() }
        LaunchMetrics.trackSDK("ARSDK")   { ARSDK.setup() }

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
