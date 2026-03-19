import UIKit
import WeChatUI
import SnapKit
import RouterKit

public final class NearbyViewController: BaseViewController {
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "附近的人"

        let label = UILabel()
        label.text = "附近的人"
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
extension NearbyViewController: PageRoutable {
    public static let routePattern = "discover/nearby"

    public static func createPage(with params: [String: String]) -> UIViewController? {
        return NearbyViewController()
    }
}
