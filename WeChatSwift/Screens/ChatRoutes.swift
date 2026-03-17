import UIKit
import RouterKit
import ChatModule

extension ChatViewController: ModuleRoutable {
    static func registerRoutes() {
        Router.shared.register("chat/detail") { params in
            guard let chatId = params["chatId"],
                  let name = params["contactName"] else { return nil }
            return RNChatDetailViewController(chatId: chatId, contactName: name)
        }
    }
}
