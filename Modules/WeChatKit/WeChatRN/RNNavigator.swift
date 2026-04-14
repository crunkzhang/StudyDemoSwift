import UIKit
import NavigateKit
import WeChatRouter

/// 原生代码直接打开 RN 页面的便捷入口。
///
/// 与 `Router.shared.push("wechat://rn?page=...")` 的区别：
/// - Router 走 URL 通道，params 只能是 `[String: String]`
/// - RNNavigator 走代码通道，params 支持 `[String: Any]`（数字、数组、嵌套对象等富类型）
public enum RNNavigator {

    public static func push(pageName: String,
                            params: [String: Any] = [:],
                            animated: Bool = true) {
        let vc = RNBaseViewController(pageName: pageName, params: params)
        Navigate.push(vc, animated: animated)
    }

    public static func replaceTop(pageName: String,
                                  params: [String: Any] = [:],
                                  animated: Bool = true) {
        let vc = RNBaseViewController(pageName: pageName, params: params)
        Navigate.replaceTop(vc, animated: animated)
    }
}
