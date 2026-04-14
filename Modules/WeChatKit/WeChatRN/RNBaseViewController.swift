import UIKit
import React
import WeChatUI
import WeChatRouter

open class RNBaseViewController: BaseViewController {
    public static let rootModuleName = "WeChatRN"
    public static let pageQueryKey = "page"

    private let pageName: String
    private let params: [String: Any]

    public init(pageName: String, params: [String: Any] = [:]) {
        self.pageName = pageName
        self.params = params
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

        let initialProps: [String: Any] = [
            "pageName": pageName,
            "params": params,
        ]
        let rnView = factory.rootViewFactory.view(
            withModuleName: Self.rootModuleName,
            initialProperties: initialProps
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
        guard let pageName = params[pageQueryKey], !pageName.isEmpty else { return nil }
        var rest = params
        rest.removeValue(forKey: pageQueryKey)
        return RNBaseViewController(pageName: pageName, params: rest)
    }
}
