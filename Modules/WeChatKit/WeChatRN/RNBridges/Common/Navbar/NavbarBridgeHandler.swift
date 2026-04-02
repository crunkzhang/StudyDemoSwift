import UIKit

private enum NavbarBridgeSignals {
    static let rightItemPress = "navbarBridge:rightItemPress"
}

final class NavbarBridgeHandler {
    static let shared = NavbarBridgeHandler()

    private var pendingOptions: NavbarOptions?
    private var rightActionId: String?

    private init() {}

    func setCurrentViewController(_ viewController: UIViewController) {
        RNBridgeContext.shared.currentViewController = viewController
        if let pendingOptions {
            apply(options: pendingOptions)
            self.pendingOptions = nil
        }
    }

    func apply(options: NavbarOptions) {
        guard let viewController = RNBridgeContext.shared.currentViewController else {
            pendingOptions = options
            return
        }
        guard let navigationController = viewController.navigationController else { return }

        switch options.mode {
        case .native:
            navigationController.setNavigationBarHidden(false, animated: options.resolvedAnimated)
            navigationController.navigationBar.prefersLargeTitles = false
            viewController.navigationItem.title = options.title
            applyAppearance(options.appearance, to: navigationController)
            applyRightItem(options.rightItem, to: viewController)
        case .rn:
            navigationController.setNavigationBarHidden(true, animated: options.resolvedAnimated)
            viewController.navigationItem.title = options.title
            viewController.navigationItem.rightBarButtonItem = nil
            rightActionId = nil
        }
    }

    func restoreNativeNavigationIfNeeded(for viewController: UIViewController) {
        guard viewController === RNBridgeContext.shared.currentViewController else { return }
        guard let navigationController = viewController.navigationController else { return }

        navigationController.setNavigationBarHidden(false, animated: false)
        navigationController.navigationBar.prefersLargeTitles = false
        resetAppearance(for: navigationController)
        viewController.navigationItem.rightBarButtonItem = nil
        RNBridgeContext.shared.currentViewController = nil
        rightActionId = nil
    }

    func goBack(animated: Bool) {
        guard let viewController = RNBridgeContext.shared.currentViewController else { return }

        if let navigationController = viewController.navigationController,
           navigationController.viewControllers.count > 1 {
            navigationController.popViewController(animated: animated)
            return
        }

        if viewController.presentingViewController != nil {
            viewController.dismiss(animated: animated)
        }
    }

    private func applyRightItem(_ item: NavbarRightItem?, to viewController: UIViewController) {
        guard let item else {
            viewController.navigationItem.rightBarButtonItem = nil
            rightActionId = nil
            return
        }

        rightActionId = item.actionId
        viewController.navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: item.title,
            style: .plain,
            target: self,
            action: #selector(handleRightItemTap)
        )
    }

    private func applyAppearance(_ appearance: NavbarAppearance?, to navigationController: UINavigationController) {
        let navigationBar = navigationController.navigationBar
        let navAppearance = UINavigationBarAppearance()

        if appearance?.resolvedTransparent == true {
            navAppearance.configureWithTransparentBackground()
            navAppearance.backgroundColor = .clear
        } else {
            navAppearance.configureWithDefaultBackground()
            if let backgroundColor = UIColor(hexString: appearance?.backgroundColor) {
                navAppearance.backgroundColor = backgroundColor
            }
        }

        if appearance?.resolvedShadowHidden == true {
            navAppearance.shadowColor = .clear
        }

        if let tintColor = UIColor(hexString: appearance?.tintColor) {
            navigationBar.tintColor = tintColor
        } else {
            navigationBar.tintColor = nil
        }

        let resolvedTitleColor = UIColor(hexString: appearance?.titleColor)
            ?? UIColor(hexString: appearance?.tintColor)

        if let titleColor = resolvedTitleColor {
            navAppearance.titleTextAttributes = [.foregroundColor: titleColor]
            navAppearance.largeTitleTextAttributes = [.foregroundColor: titleColor]
            navigationBar.titleTextAttributes = [.foregroundColor: titleColor]
            navigationBar.largeTitleTextAttributes = [.foregroundColor: titleColor]
        } else {
            navigationBar.titleTextAttributes = [:]
            navigationBar.largeTitleTextAttributes = [:]
        }

        navigationBar.standardAppearance = navAppearance
        navigationBar.scrollEdgeAppearance = navAppearance
        navigationBar.compactAppearance = navAppearance
        navigationBar.compactScrollEdgeAppearance = navAppearance
    }

    private func resetAppearance(for navigationController: UINavigationController) {
        let navigationBar = navigationController.navigationBar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithDefaultBackground()

        navigationBar.tintColor = nil
        navigationBar.standardAppearance = navAppearance
        navigationBar.scrollEdgeAppearance = navAppearance
        navigationBar.compactAppearance = navAppearance
        navigationBar.compactScrollEdgeAppearance = navAppearance
    }

    @objc
    private func handleRightItemTap() {
        guard let actionId = rightActionId else { return }
        RNBridgeContext.shared.emit(
            signal: NavbarBridgeSignals.rightItemPress,
            payload: ["actionId": actionId]
        )
    }
}

private extension UIColor {
    convenience init?(hexString: String?) {
        guard let hexString else { return nil }
        let trimmed = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("#") else { return nil }

        let hex = String(trimmed.dropFirst())
        guard hex.count == 6 || hex.count == 8 else { return nil }

        var value: UInt64 = 0
        guard Scanner(string: hex).scanHexInt64(&value) else { return nil }

        let hasAlpha = hex.count == 8
        let red = CGFloat((value >> (hasAlpha ? 24 : 16)) & 0xFF) / 255
        let green = CGFloat((value >> (hasAlpha ? 16 : 8)) & 0xFF) / 255
        let blue = CGFloat((value >> (hasAlpha ? 8 : 0)) & 0xFF) / 255
        let alpha = hasAlpha ? CGFloat(value & 0xFF) / 255 : 1

        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
