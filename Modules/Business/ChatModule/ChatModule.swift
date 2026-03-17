import UIKit
import RouterKit
import WeChatRNKit

extension ChatModule: ModuleRoutable {
    public static func registerRoutes() {
        // RN 页面：使用 RNBaseViewController，参数透传
        Router.shared.register("chat/detail") { params in
            return RNBaseViewController(
                moduleName: "ChatDetail",
                props: params
            )
        }
    }
}

public class ChatModule {
    public static let shared = ChatModule()
    private init() {}
}
