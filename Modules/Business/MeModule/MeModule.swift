import UIKit
import WeChatRouter

extension MeModule: ModuleRoutable {
    public static func registerRoutes() {
        // 个人中心相关路由注册
        // 未来可以添加：
        // Router.register("wechat://me/profile") { ... }
        // Router.register("wechat://me/settings") { ... }
        // Router.register("wechat://me/wallet") { ... }
    }
}

public class MeModule {
    public static let shared = MeModule()
    private init() {}
}
