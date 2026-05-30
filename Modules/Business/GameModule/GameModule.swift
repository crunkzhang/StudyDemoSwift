import UIKit
import WeChatRouter

extension GameModule: ModuleRoutable {
    public static func registerRoutes() {
        GameHallViewController.registerPageRoute()
        GameRunnerViewController.registerPageRoute()
    }
}

public class GameModule {
    public static let shared = GameModule()
    private init() {}
}
