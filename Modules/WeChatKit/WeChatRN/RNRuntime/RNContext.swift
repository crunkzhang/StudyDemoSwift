import UIKit

/// RN 运行时共享上下文 —— 跨 Bridge 共享的原生侧状态。
/// 以后要加 currentPageName / 主题 / 登录态等，都往这里加。
public final class RNContext {
    public static let shared = RNContext()
    private init() {}

    // MARK: - Current View Controller

    public private(set) weak var currentViewController: UIViewController?

    private var vcObservers: [(UIViewController?) -> Void] = []

    /// 仅由 RNBaseViewController 的生命周期调用；其他地方只读或订阅。
    public func setCurrentViewController(_ vc: UIViewController?) {
        currentViewController = vc
        vcObservers.forEach { $0(vc) }
    }

    /// 订阅当前 VC 变化 —— 订阅方通常是 Bridge Handler 单例，永久持有。
    public func observeCurrentVC(_ handler: @escaping (UIViewController?) -> Void) {
        vcObservers.append(handler)
    }
}
