import UIKit
import React
import React_RCTAppDelegate
import ReactAppDependencyProvider
import WeChatUI

/// RN Factory 管理器 —— RN 启动的唯一入口
public class RNFactoryManager {
    public static let shared = RNFactoryManager()
    public private(set) var factory: RCTReactNativeFactory?
    private var needsReload = false

    private var delegate: RNAppDelegate?

    private init() {}

    /// 初始化 React Native，由主工程 AppDelegate 调用一次
    public func setup() {
        guard factory == nil else { return }

        let appDelegate = RNAppDelegate()
        appDelegate.dependencyProvider = RCTAppDependencyProvider()
        delegate = appDelegate
        factory = RCTReactNativeFactory(delegate: appDelegate)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBundleUpdate),
            name: .rnBundleDidUpdate,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleVCDidAppear(_:)),
            name: .baseVCDidAppear,
            object: nil
        )
    }
}

// MARK: - Private

private extension RNFactoryManager {
    @objc func handleBundleUpdate() {
        needsReload = true
        reloadIfNeeded()
    }

    @objc func handleVCDidAppear(_ notification: Notification) {
        reloadIfNeeded()
    }

    func reloadIfNeeded() {
        guard needsReload else { return }
        guard !hasRNPageInStack() else { return }
        guard let delegate else { return }

        factory = RCTReactNativeFactory(delegate: delegate)
        needsReload = false
        print("[RNBundle][Load] Bridge 已重建，加载新 bundle")
    }

    func hasRNPageInStack() -> Bool {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first,
              let root = window.rootViewController else {
            return false
        }
        return collectNavigationControllers(from: root)
            .flatMap { $0.viewControllers }
            .contains { $0 is RNBaseViewController }
    }

    func collectNavigationControllers(from vc: UIViewController) -> [UINavigationController] {
        var result: [UINavigationController] = []
        if let nav = vc as? UINavigationController {
            result.append(nav)
        } else if let tab = vc as? UITabBarController {
            for child in tab.viewControllers ?? [] {
                result.append(contentsOf: collectNavigationControllers(from: child))
            }
        }
        if let presented = vc.presentedViewController {
            result.append(contentsOf: collectNavigationControllers(from: presented))
        }
        return result
    }
}

// MARK: - RN 配置代理（内部使用）

private class RNAppDelegate: RCTDefaultReactNativeFactoryDelegate {
    override func sourceURL(for bridge: RCTBridge) -> URL? {
        bundleURL()
    }

    override func bundleURL() -> URL? {
        // 优先级:已下载远程 bundle → 内置兜底
        // DEBUG/RELEASE 走同一链路,验证远程更新/灰度/回滚行为一致。
        // 想用 Metro Fast Refresh 调试时,把下面 useMetro 改 true。
        let useMetro = false
        if useMetro {
            if let metro = RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: "index") {
                print("[RNBundle][Load] 加载 Metro: \(metro.absoluteString)")
                return metro
            }
        }
        if let downloaded = RNBundleManager.shared.bundlePath {
            print("[RNBundle][Load] 加载已下载 bundle: \(downloaded.path)")
            return downloaded
        }
        let builtin = Bundle.main.url(forResource: "main", withExtension: "jsbundle")
        print("[RNBundle][Load] 加载内置兜底 bundle: \(builtin?.path ?? "nil")")
        return builtin
    }
}
