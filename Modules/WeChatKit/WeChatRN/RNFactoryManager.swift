import Foundation
import React
import React_RCTAppDelegate
import ReactAppDependencyProvider

/// RN Factory 管理器 —— RN 启动的唯一入口
public class RNFactoryManager {
    public static let shared = RNFactoryManager()
    public private(set) var factory: RCTReactNativeFactory?

    private var delegate: RNAppDelegate?

    private init() {}

    /// 初始化 React Native，由主工程 AppDelegate 调用一次
    public func setup() {
        let appDelegate = RNAppDelegate()
        appDelegate.dependencyProvider = RCTAppDependencyProvider()
        delegate = appDelegate
        factory = RCTReactNativeFactory(delegate: appDelegate)
    }
}

// MARK: - RN 配置代理（内部使用）

private class RNAppDelegate: RCTDefaultReactNativeFactoryDelegate {
    override func sourceURL(for bridge: RCTBridge) -> URL? {
        bundleURL()
    }

    override func bundleURL() -> URL? {
    #if DEBUG
        RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: "index")
    #else
        Bundle.main.url(forResource: "main", withExtension: "jsbundle")
    #endif
    }
}
