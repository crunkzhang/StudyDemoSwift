import Foundation
import WeChatRouter

extension DSLKit: ModuleRoutable {
    /// 注册 wechat://page?id=xxx → 通用 DSL 页容器
    public static func registerRoutes() {
        DSLPageViewController.registerPageRoute()
    }
}
