import UIKit

public final class PageTracker {

    public static let shared = PageTracker()

    private var currentPageName: String?
    private let lock = NSLock()
    private var swizzled = false

    private init() {}

    /// 获取当前页面类名
    public var currentPage: String? {
        lock.lock()
        defer { lock.unlock() }
        return currentPageName
    }

    /// 启动 swizzle，自动追踪页面切换
    public func start() {
        guard !swizzled else { return }
        swizzled = true
        swizzleViewDidAppear()
    }

    /// 手动设置当前页面（优先级高于自动追踪）
    public func setCurrentPage(_ name: String) {
        lock.lock()
        currentPageName = name
        lock.unlock()
    }

    // MARK: - Swizzle

    private func swizzleViewDidAppear() {
        let originalSelector = #selector(UIViewController.viewDidAppear(_:))
        let swizzledSelector = #selector(UIViewController.caton_viewDidAppear(_:))

        guard let originalMethod = class_getInstanceMethod(UIViewController.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(UIViewController.self, swizzledSelector)
        else { return }

        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
}

// MARK: - UIViewController Swizzle

extension UIViewController {

    @objc func caton_viewDidAppear(_ animated: Bool) {
        // 调用原始实现（已交换，所以调 caton_ 就是调原始）
        caton_viewDidAppear(animated)

        // 过滤系统容器 VC，只记录内容页面
        let isContainer = self is UINavigationController
            || self is UITabBarController
            || self is UISplitViewController

        if !isContainer {
            let pageName = String(describing: type(of: self))
            PageTracker.shared.setCurrentPage(pageName)
        }
    }
}
