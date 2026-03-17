import UIKit

public protocol Routable {
    static func registerRoutes()
}

public final class Router {
    public static let shared = Router()

    private var routes: [String: ([String: String]) -> UIViewController?] = [:]

    private init() {}

    public func register(_ pattern: String, handler: @escaping ([String: String]) -> UIViewController?) {
        routes[pattern] = handler
    }

    public func registerModules(_ modules: [Routable.Type]) {
        modules.forEach { $0.registerRoutes() }
    }

    public func push(_ url: String, animated: Bool = true) {
        guard let (vc, _) = resolve(url) else { return }
        topNavigationController()?.pushViewController(vc, animated: animated)
    }

    public func present(_ url: String, animated: Bool = true, completion: (() -> Void)? = nil) {
        guard let (vc, _) = resolve(url) else { return }
        topViewController()?.present(vc, animated: animated, completion: completion)
    }

    public func resolve(_ url: String) -> (UIViewController, [String: String])? {
        guard let components = URLComponents(string: url) else { return nil }

        // Extract path: scheme://host/path → "host/path"
        let host = components.host ?? ""
        let path = components.path.hasPrefix("/") ? String(components.path.dropFirst()) : components.path
        let pattern = path.isEmpty ? host : "\(host)/\(path)"

        // Parse query parameters
        var params: [String: String] = [:]
        components.queryItems?.forEach { item in
            params[item.name] = item.value
        }

        guard let handler = routes[pattern], let vc = handler(params) else { return nil }
        return (vc, params)
    }

    // MARK: - Helper

    private func topNavigationController() -> UINavigationController? {
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

    private func topViewController() -> UIViewController? {
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
