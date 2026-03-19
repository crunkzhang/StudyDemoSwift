import UIKit
import WeChatUI
import SnapKit
import WeChatRouter

public final class MomentsViewController: BaseViewController {
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "朋友圈"

        let label = UILabel()
        label.text = "朋友圈"
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
extension MomentsViewController: PageRoutable {
    public static let routePattern = "discover/moments"

    public static func createPage(with params: [String: String]) -> UIViewController? {
        return MomentsViewController()
    }
}
