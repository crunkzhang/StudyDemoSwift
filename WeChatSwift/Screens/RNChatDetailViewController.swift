import UIKit
import React
import SnapKit

class RNChatDetailViewController: UIViewController {
    private let chatId: String
    private let contactName: String

    init(chatId: String, contactName: String) {
        self.chatId = chatId
        self.contactName = contactName
        super.init(nibName: nil, bundle: nil)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = contactName
        view.backgroundColor = .white

        guard let factory = (UIApplication.shared.delegate as? AppDelegate)?.reactNativeFactory else {
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
