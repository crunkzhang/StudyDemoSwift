import UIKit
import RouterKit

extension ChatModule: ModuleRoutable {
    public static func registerRoutes() {
        RNBaseViewController.registerRNRoute(
            pattern: "chat/detail",
            moduleName: "ChatDetail"
        )
    }
}

public class ChatModule {
    public static let shared = ChatModule()
    private init() {}
}
