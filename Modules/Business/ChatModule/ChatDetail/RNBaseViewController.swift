import UIKit
import SnapKit
import React
import WeChatUI
import RouterKit

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

// MARK: - Route Registration
extension RNBaseViewController {

    /// 注册 RN 页面路由
    /// - Parameters:
    ///   - pattern: 路由模式，如 "chat/detail"
    ///   - moduleName: RN 模块名，如 "ChatDetail"
    ///   - propsTransformer: 将路由参数转换为 RN props，默认透传
    public static func registerRNRoute(
        pattern: String,
        moduleName: String
    ) {
        Router.shared.register(pattern) { params in
            return RNBaseViewController(moduleName: moduleName, props: params)
        }
    }
}
