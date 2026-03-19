import UIKit

public final class Navigate {

    public static func push(_ vc: UIViewController, animated: Bool = true) {
        vc.hidesBottomBarWhenPushed = true
        topNavigationController()?.pushViewController(vc, animated: animated)
    }

    public static func present(_ vc: UIViewController, animated: Bool = true, completion: (() -> Void)? = nil) {
        topViewController()?.present(vc, animated: animated, completion: completion)
    }

    public static func topNavigationController() -> UINavigationController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let root = window.rootViewController else { return nil }

        if let tab = root as? UITabBarController,
           let nav = tab.selectedViewController as? UINavigationController {
            return nav
        }
        if let nav = root as? UINavigationController {
            return nav
        }
        return root.navigationController
    }

    public static func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }),
              let root = window.rootViewController else { return nil }

        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
