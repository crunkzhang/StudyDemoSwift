import UIKit
import RouterKit

extension MeModuleEntry: Routable {
    public static func registerRoutes() {
        // 个人中心相关路由注册
        // 未来可以添加：
        // Router.shared.register("wechat://me/profile") { ... }
        // Router.shared.register("wechat://me/settings") { ... }
        // Router.shared.register("wechat://me/wallet") { ... }
    }
}

public class MeModuleEntry {
    public static let shared = MeModuleEntry()
    private init() {}
}
