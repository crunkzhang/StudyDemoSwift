import Foundation
import UIKit
import NavigateKit
import WeChatRouter

@objc(NavigationBridge)
final class NavigationBridge: NSObject {

    @objc static func requiresMainQueueSetup() -> Bool { true }

    @objc(push:)
    func push(_ payload: NSDictionary) {
        guard let pageName = payload["pageName"] as? String, !pageName.isEmpty else { return }
        let params = (payload["params"] as? [String: Any]) ?? [:]
        let animated = (payload["animated"] as? Bool) ?? true
        DispatchQueue.main.async {
            let vc = RNBaseViewController(pageName: pageName, params: params)
            Navigate.push(vc, animated: animated)
        }
    }

    @objc(pop:)
    func pop(_ payload: NSDictionary) {
        let animated = (payload["animated"] as? Bool) ?? true
        // 一期忽略 payload["result"]（预留二期返回值通道）
        DispatchQueue.main.async {
            Navigate.pop(animated: animated)
        }
    }

    @objc(replace:)
    func replace(_ payload: NSDictionary) {
        guard let pageName = payload["pageName"] as? String, !pageName.isEmpty else { return }
        let params = (payload["params"] as? [String: Any]) ?? [:]
        let animated = (payload["animated"] as? Bool) ?? true
        DispatchQueue.main.async {
            let vc = RNBaseViewController(pageName: pageName, params: params)
            Navigate.replaceTop(vc, animated: animated)
        }
    }

    @objc(pushURL:)
    func pushURL(_ url: NSString) {
        let urlString = url as String
        DispatchQueue.main.async {
            Router.shared.push(urlString)
        }
    }

    @objc(replaceURL:)
    func replaceURL(_ url: NSString) {
        let urlString = url as String
        DispatchQueue.main.async {
            guard let (vc, _) = Router.shared.resolve(urlString) else { return }
            Navigate.replaceTop(vc)
        }
    }
}
