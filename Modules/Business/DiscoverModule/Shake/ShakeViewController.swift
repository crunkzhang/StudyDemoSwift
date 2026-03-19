import UIKit
import WeChatUI
import SnapKit
import WeChatRouter

public final class ShakeViewController: BaseViewController {
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "摇一摇"

        let label = UILabel()
        label.text = "摇一摇"
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
extension ShakeViewController: PageRoutable {
    public static let routePattern = "discover/shake"

    public static func createPage(with params: [String: String]) -> UIViewController? {
        return ShakeViewController()
    }
}
