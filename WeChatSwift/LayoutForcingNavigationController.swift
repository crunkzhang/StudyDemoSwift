import UIKit

final class LayoutForcingNavigationController: UINavigationController {
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        viewController.loadViewIfNeeded()
        viewController.view.frame = view.bounds
        viewController.view.layoutIfNeeded()
        super.pushViewController(viewController, animated: animated)
        viewController.transitionCoordinator?.animate { _ in
            UIView.performWithoutAnimation {
                viewController.view.layoutIfNeeded()
            }
        }
    }
}
