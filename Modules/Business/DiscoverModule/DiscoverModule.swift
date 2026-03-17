import UIKit
import RouterKit

extension DiscoverModule: ModuleRoutable {
    public static func registerRoutes() {
        MomentsViewController.registerRoute()
        VideoChannelViewController.registerRoute()
        ScanViewController.registerRoute()
        ShakeViewController.registerRoute()
        NearbyViewController.registerRoute()
        ShoppingViewController.registerRoute()
        GameViewController.registerRoute()
        SearchViewController.registerRoute()
    }
}

public class DiscoverModule {
    public static let shared = DiscoverModule()
    private init() {}
}
