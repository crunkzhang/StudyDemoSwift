import UIKit
import WeChatRN
import ChatModule
import ContactModule
import DiscoverModule
import MeModule

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        RNFactoryManager.shared.setup()
        RNBundleUpdater.shared.remoteBaseURL = "https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com/ios/v1"
        RNBundleUpdater.shared.checkUpdate()

        RNBaseViewController.registerPageRoute()
        ChatModule.registerRoutes()
        ContactModule.registerRoutes()
        DiscoverModule.registerRoutes()
        MeModule.registerRoutes()

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
