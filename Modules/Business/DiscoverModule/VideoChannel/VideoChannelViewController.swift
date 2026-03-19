import UIKit
import WeChatUI
import SnapKit
import WeChatRouter

public final class VideoChannelViewController: BaseViewController {
    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "视频号"

        let label = UILabel()
        label.text = "视频号"
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
extension VideoChannelViewController: PageRoutable {
    public static let routePattern = "discover/videoChannel"

    public static func createPage(with params: [String: String]) -> UIViewController? {
        return VideoChannelViewController()
    }
}
