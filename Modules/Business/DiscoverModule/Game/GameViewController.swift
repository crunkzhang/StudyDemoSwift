import UIKit
import WeChatUI
import SnapKit
import RouterKit

public final class GameViewController: BaseViewController {
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "游戏"

        let label = UILabel()
        label.text = "游戏"
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
extension GameViewController: VCRoutable {
    public static let routePattern = "discover/game"

    public static func create(with params: [String: String]) -> UIViewController? {
        return GameViewController()
    }
}
