import UIKit
import WeChatRouter

extension ContactModule: ModuleRoutable {
    public static func registerRoutes() {
        // 通讯录相关路由注册
        // 未来可以添加：
        // Router.register("wechat://contact/detail") { ... }
        // Router.register("wechat://contact/add") { ... }
    }
}

public class ContactModule {
    public static let shared = ContactModule()
    private init() {}
}
