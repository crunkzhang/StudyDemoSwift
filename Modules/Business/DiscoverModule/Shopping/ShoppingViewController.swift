import UIKit
import WeChatUI
import SnapKit
import RouterKit

public final class ShoppingViewController: BaseViewController {
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "购物"

        let label = UILabel()
        label.text = "购物"
        label.font = .systemFont(ofSize: 20, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        view.addSubview(label)
        label.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalTo(view.safeAreaLayoutGuide)
        }
    }
}

// MARK: - PageRoutable
extension ShoppingViewController: PageRoutable {
    public static let routePattern = "discover/shopping"

    public static func createPage(with params: [String: String]) -> UIViewController? {
        return ShoppingViewController()
    }
}
