import UIKit
import NavigateKit

public protocol ModuleRoutable {
    static func registerRoutes()
}

public protocol PageRoutable {
    static var routePattern: String { get }
    static func createPage(with params: [String: String]) -> UIViewController?
}

public extension PageRoutable where Self: UIViewController {

    static func registerPageRoute() {
        Router.shared.register(routePattern) { params in
            return createPage(with: params)
        }
    }
}

public final class Router {
    public static let shared = Router()

    private var routes: [String: ([String: String]) -> UIViewController?] = [:]

    private init() {}

    public func register(_ pattern: String, handler: @escaping ([String: String]) -> UIViewController?) {
        routes[pattern] = handler
    }

    public func push(_ url: String, animated: Bool = true) {
        guard let (vc, _) = resolve(url) else { return }
        Navigate.push(vc, animated: animated)
    }

    public func present(_ url: String, animated: Bool = true, completion: (() -> Void)? = nil) {
        guard let (vc, _) = resolve(url) else { return }
        Navigate.present(vc, animated: animated, completion: completion)
    }

    public func resolve(_ url: String) -> (UIViewController, [String: String])? {
        guard let components = URLComponents(string: url) else { return nil }

        let host = components.host ?? ""
        let path = components.path.hasPrefix("/") ? String(components.path.dropFirst()) : components.path
        let pattern = path.isEmpty ? host : "\(host)/\(path)"

        var params: [String: String] = [:]
        components.queryItems?.forEach { item in
            params[item.name] = item.value
        }

        guard let handler = routes[pattern], let vc = handler(params) else { return nil }
        return (vc, params)
    }
}
