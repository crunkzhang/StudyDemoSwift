import UIKit
import RouterKit

extension ChatModule: ModuleRoutable {
    public static func registerRoutes() {
        RNChatDetailViewController.registerRoute()
    }
}

public class ChatModule {
    public static let shared = ChatModule()
    private init() {}
}
