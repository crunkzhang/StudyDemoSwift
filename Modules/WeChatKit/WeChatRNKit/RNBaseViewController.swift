import UIKit
import SnapKit
import React
import WeChatUI

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
}
