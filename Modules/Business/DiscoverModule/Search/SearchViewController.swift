import UIKit
import WeChatUI
import SnapKit
import RouterKit

public final class SearchViewController: BaseViewController {
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "搜一搜"

        let label = UILabel()
        label.text = "搜一搜"
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

// MARK: - VCRoutable
extension SearchViewController: VCRoutable {
    public static let routePattern = "discover/search"

    public static func create(with params: [String: String]) -> UIViewController? {
        return SearchViewController()
    }
}
