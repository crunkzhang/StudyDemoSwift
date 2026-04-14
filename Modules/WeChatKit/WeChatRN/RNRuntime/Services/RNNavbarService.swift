import UIKit

/// RN 导航栏能力：监听当前 VC 变化，应用/还原导航栏外观与右侧按钮，并在点击时派发事件。
final class RNNavbarService {
    static let shared = RNNavbarService()

    private var pendingOptions: NavbarOptions?
    private var rightActionId: String?
    private weak var trackedVC: UIViewController?

    private init() {
        RNContext.shared.observeCurrentVC { [weak self] vc in
            self?.handleCurrentVCChange(vc)
        }
    }

    func apply(options: NavbarOptions) {
        guard let viewController = RNContext.shared.currentViewController else {
            pendingOptions = options
            return
        }
        applyInternal(options: options, to: viewController)
    }

    private func handleCurrentVCChange(_ newVC: UIViewController?) {
        if let tracked = trackedVC, tracked !== newVC {
            restoreAppearance(on: tracked)
            trackedVC = nil
            rightActionId = nil
        }
        if let newVC, let pending = pendingOptions {
            pendingOptions = nil
            applyInternal(options: pending, to: newVC)
        }
    }

    private func applyInternal(options: NavbarOptions, to viewController: UIViewController) {
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
        trackedVC = viewController
    }

    private func restoreAppearance(on viewController: UIViewController) {
        guard let navigationController = viewController.navigationController else { return }

        navigationController.setNavigationBarHidden(false, animated: false)
        navigationController.navigationBar.prefersLargeTitles = false
        resetAppearance(for: navigationController)
        viewController.navigationItem.rightBarButtonItem = nil
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
        EventBus.emit(NavbarEvents.rightItemPress, payload: ["actionId": actionId])
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
