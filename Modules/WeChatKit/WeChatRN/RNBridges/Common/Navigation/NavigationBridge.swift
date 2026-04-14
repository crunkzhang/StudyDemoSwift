import Foundation
import UIKit
import NavigateKit
import WeChatRouter

@objc(NavigationBridge)
final class NavigationBridge: NSObject {

    @objc static func requiresMainQueueSetup() -> Bool { true }

    @objc func push(_ payload: NSDictionary) {
        guard let pageName = payload["pageName"] as? String, !pageName.isEmpty else { return }
        let params = (payload["params"] as? [String: Any]) ?? [:]
        let animated = (payload["animated"] as? Bool) ?? true
        DispatchQueue.main.async {
            let vc = RNBaseViewController(pageName: pageName, params: params)
            Navigate.push(vc, animated: animated)
        }
    }

    @objc func pop(_ payload: NSDictionary) {
        let animated = (payload["animated"] as? Bool) ?? true
        DispatchQueue.main.async {
            Navigate.pop(animated: animated)
        }
    }

    @objc func replace(_ payload: NSDictionary) {
        guard let pageName = payload["pageName"] as? String, !pageName.isEmpty else { return }
        let params = (payload["params"] as? [String: Any]) ?? [:]
        let animated = (payload["animated"] as? Bool) ?? true
        DispatchQueue.main.async {
            let vc = RNBaseViewController(pageName: pageName, params: params)
            Navigate.replaceTop(vc, animated: animated)
        }
    }

    @objc func pushURL(_ url: NSString) {
        let urlString = url as String
        DispatchQueue.main.async {
            Router.shared.push(urlString)
        }
    }

    @objc func present(_ payload: NSDictionary) {
        guard let pageName = payload["pageName"] as? String, !pageName.isEmpty else { return }
        let params = (payload["params"] as? [String: Any]) ?? [:]
        let animated = (payload["animated"] as? Bool) ?? true
        let style = payload["presentationStyle"] as? String
        DispatchQueue.main.async {
            let rnVC = RNBaseViewController(pageName: pageName, params: params)
            let nav = UINavigationController(rootViewController: rnVC)
            switch style {
            case "sheet": break
            default: nav.modalPresentationStyle = .fullScreen
            }
            Navigate.present(nav, animated: animated)
        }
    }

    @objc func dismiss(_ payload: NSDictionary) {
        let animated = (payload["animated"] as? Bool) ?? true
        DispatchQueue.main.async {
            RNContext.shared.currentViewController?.dismiss(animated: animated)
        }
    }

    @objc func goBack(_ payload: NSDictionary) {
        let animated = (payload["animated"] as? Bool) ?? true
        DispatchQueue.main.async {
            guard let vc = RNContext.shared.currentViewController else { return }
            if let nav = vc.navigationController, nav.viewControllers.count > 1 {
                nav.popViewController(animated: animated)
                return
            }
            if vc.presentingViewController != nil {
                vc.dismiss(animated: animated)
            }
        }
    }

    @objc func replaceURL(_ url: NSString) {
        let urlString = url as String
        DispatchQueue.main.async {
            guard let (vc, _) = Router.shared.resolve(urlString) else { return }
            Navigate.replaceTop(vc)
        }
    }
}
