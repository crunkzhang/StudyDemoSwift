import UIKit
import WeChatRouter

extension ChatModule: ModuleRoutable {
    public static func registerRoutes() {}
}

public class ChatModule {
    public static let shared = ChatModule()
    private init() {}
}
