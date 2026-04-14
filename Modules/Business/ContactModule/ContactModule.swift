import UIKit
import WeChatRouter

extension ContactModule: ModuleRoutable {
    public static func registerRoutes() {
        Router.shared.register("contact/detail") { params in
            let data = MockContactData.generate()
            let all = data.grouped.values.flatMap { $0 }
            let id = params["id"] ?? ""
            let contact = all.first { $0.id == id } ?? all.first!
            return ContactDetailViewController(contact: contact)
        }
    }
}

public class ContactModule {
    public static let shared = ContactModule()
    private init() {}
}
