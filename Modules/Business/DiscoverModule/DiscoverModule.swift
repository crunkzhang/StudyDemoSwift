import UIKit
import RouterKit

extension DiscoverModule: ModuleRoutable {
    public static func registerRoutes() {
        MomentsViewController.registerPageRoute()
        VideoChannelViewController.registerPageRoute()
        ScanViewController.registerPageRoute()
        ShakeViewController.registerPageRoute()
        NearbyViewController.registerPageRoute()
        ShoppingViewController.registerPageRoute()
        GameViewController.registerPageRoute()
        SearchViewController.registerPageRoute()
    }
}

public class DiscoverModule {
    public static let shared = DiscoverModule()
    private init() {}
}
