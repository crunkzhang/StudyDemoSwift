import UIKit
import RouterKit

extension DiscoverModule: ModuleRoutable {
    public static func registerRoutes() {
        Router.shared.register("discover/moments") { _ in MomentsViewController() }
        Router.shared.register("discover/videoChannel") { _ in VideoChannelViewController() }
        Router.shared.register("discover/scan") { _ in ScanViewController() }
        Router.shared.register("discover/shake") { _ in ShakeViewController() }
        Router.shared.register("discover/nearby") { _ in NearbyViewController() }
        Router.shared.register("discover/shopping") { _ in ShoppingViewController() }
        Router.shared.register("discover/game") { _ in GameViewController() }
        Router.shared.register("discover/search") { _ in SearchViewController() }
    }
}

public class DiscoverModule {
    public static let shared = DiscoverModule()
    private init() {}
}
