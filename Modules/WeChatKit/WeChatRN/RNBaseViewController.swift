import UIKit
import SnapKit
import React
import WeChatUI
import WeChatRouter

open class RNBaseViewController: BaseViewController {
    private let moduleName: String
    private let props: [String: Any]

    public init(moduleName: String, props: [String: Any] = [:]) {
        self.moduleName = moduleName
        self.props = props
        super.init(nibName: nil, bundle: nil)
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        guard let factory = RNFactoryManager.shared.factory else {
            return
        }

        let rnView = factory.rootViewFactory.view(
            withModuleName: moduleName,
            initialProperties: props
        )
        view.addSubview(rnView)

        rnView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        NavbarBridgeHandler.shared.setCurrentViewController(self)
    }

    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NavbarBridgeHandler.shared.setCurrentViewController(self)
    }

    open override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        if isMovingFromParent || isBeingDismissed {
            NavbarBridgeHandler.shared.restoreNativeNavigationIfNeeded(for: self)
        }
    }
}

// MARK: - Route Registration
extension RNBaseViewController: PageRoutable {

    public static let routePattern = "rn"

    public static func createPage(with params: [String: String]) -> UIViewController? {
        guard let moduleName = params["module"] else { return nil }
        return RNBaseViewController(moduleName: moduleName, props: params)
    }
}
