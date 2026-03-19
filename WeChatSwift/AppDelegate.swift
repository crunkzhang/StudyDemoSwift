import UIKit
import React
import React_RCTAppDelegate
import ReactAppDependencyProvider
import WeChatRN
import ChatModule
import ContactModule
import DiscoverModule
import MeModule

@main
class AppDelegate: UIResponder, UIApplicationDelegate, ReactNativeFactoryProvider {
    var reactNativeDelegate: ReactNativeDelegate?
    var reactNativeFactory: RCTReactNativeFactory?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let delegate = ReactNativeDelegate()
        delegate.dependencyProvider = RCTAppDependencyProvider()
        reactNativeDelegate = delegate
        let factory = RCTReactNativeFactory(delegate: delegate)
        reactNativeFactory = factory

        // 设置 RN Factory provider
        RNFactoryManager.shared.provider = self

        // 注册所有业务模块的路由
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

class ReactNativeDelegate: RCTDefaultReactNativeFactoryDelegate {
    override func sourceURL(for bridge: RCTBridge) -> URL? {
        self.bundleURL()
    }

    override func bundleURL() -> URL? {
    #if DEBUG
        RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: "index")
    #else
        Bundle.main.url(forResource: "main", withExtension: "jsbundle")
    #endif
    }
}
