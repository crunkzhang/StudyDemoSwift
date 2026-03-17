import UIKit
import RouterKit

extension ContactModuleEntry: Routable {
    public static func registerRoutes() {
        // 通讯录相关路由注册
        // 未来可以添加：
        // Router.shared.register("wechat://contact/detail") { ... }
        // Router.shared.register("wechat://contact/add") { ... }
    }
}

public class ContactModuleEntry {
    public static let shared = ContactModuleEntry()
    private init() {}
}
