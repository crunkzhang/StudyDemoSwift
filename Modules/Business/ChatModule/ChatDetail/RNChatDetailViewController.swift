import UIKit
import WeChatUI
import React
import WeChatRNKit
import RouterKit

public class RNChatDetailViewController: BaseViewController {
    private let chatId: String
    private let contactName: String

    public init(chatId: String, contactName: String) {
        self.chatId = chatId
        self.contactName = contactName
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = contactName
        view.backgroundColor = .white

        guard let factory = RNFactoryManager.shared.factory else {
            return
        }

        let props: [String: Any] = [
            "chatId": chatId,
            "contactName": contactName,
        ]

        let rnView = factory.rootViewFactory.view(
            withModuleName: "ChatDetail",
            initialProperties: props
        )
        view.addSubview(rnView)

        rnView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

// MARK: - VCRoutable
extension RNChatDetailViewController: VCRoutable {
    public static let routePattern = "chat/detail"

    public static func create(with params: [String: String]) -> UIViewController? {
        guard let chatId = params["chatId"],
              let contactName = params["contactName"] else {
            return nil
        }
        return RNChatDetailViewController(chatId: chatId, contactName: contactName)
    }
}
