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
        RCTBundleURLProvider.sharedSettings().jsLocation = "172.27.90.56"
        return RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: "index")
    #else
        if let downloaded = RNBundleManager.shared.bundlePath {
            print("[RNBundle][Load] 加载已下载 bundle: \(downloaded.path)")
            return downloaded
        }
        let builtin = Bundle.main.url(forResource: "main", withExtension: "jsbundle")
        print("[RNBundle][Load] 加载内置兜底 bundle")
        return builtin
    #endif
    }
}
