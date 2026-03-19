import UIKit
import RouterKit

extension DiscoverModule: ModuleRoutable {
    public static func registerRoutes() {
        MomentsViewController.registerNativeRoute()
        VideoChannelViewController.registerNativeRoute()
        ScanViewController.registerNativeRoute()
        ShakeViewController.registerNativeRoute()
        NearbyViewController.registerNativeRoute()
        ShoppingViewController.registerNativeRoute()
        GameViewController.registerNativeRoute()
        SearchViewController.registerNativeRoute()
    }
}

public class DiscoverModule {
    public static let shared = DiscoverModule()
    private init() {}
}
