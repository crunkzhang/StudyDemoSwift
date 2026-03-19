import UIKit
import WeChatUI
import SnapKit
import RouterKit

public final class ScanViewController: BaseViewController {
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "扫一扫"

        let label = UILabel()
        label.text = "扫一扫"
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
extension ScanViewController: PageRoutable {
    public static let routePattern = "discover/scan"

    public static func createPage(with params: [String: String]) -> UIViewController? {
        return ScanViewController()
    }
}
