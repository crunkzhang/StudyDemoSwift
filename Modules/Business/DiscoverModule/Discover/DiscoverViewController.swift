import UIKit
import WeChatUI
import SnapKit
import ExtensionKit
import WeChatRouter
import WeChatRouter

public class DiscoverViewController: BaseViewController {
    private struct DiscoverItem {
        let icon: String
        let iconColor: UIColor
        let title: String
        let route: String
    }

    // 微信发现页分组
    private let sectionItems: [[DiscoverItem]] = [
        [
            DiscoverItem(icon: "circle.dashed", iconColor: UIColor(hex: "#FA9D3B"), title: "朋友圈", route: Routes.moments),
            DiscoverItem(icon: "video", iconColor: UIColor(hex: "#FA9D3B"), title: "视频号", route: Routes.videoChannel),
        ],
        [
            DiscoverItem(icon: "qrcode.viewfinder", iconColor: UIColor(hex: "#576B95"), title: "扫一扫", route: Routes.scan),
            DiscoverItem(icon: "hand.wave", iconColor: UIColor(hex: "#576B95"), title: "摇一摇", route: Routes.shake),
        ],
        [
            DiscoverItem(icon: "mappin.circle", iconColor: UIColor(hex: "#07C160"), title: "附近的人", route: Routes.nearby),
        ],
        [
            DiscoverItem(icon: "bag", iconColor: UIColor(hex: "#E75A5A"), title: "购物", route: Routes.shopping),
            DiscoverItem(icon: "gamecontroller", iconColor: UIColor(hex: "#07C160"), title: "游戏", route: Routes.game),
        ],
        [
            DiscoverItem(icon: "doc.text.magnifyingglass", iconColor: UIColor(hex: "#FA9D3B"), title: "搜一搜", route: Routes.search),
        ],
    ]

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.dataSource = self
        tv.delegate = self
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "DiscoverCell")
        tv.rowHeight = 52
        tv.backgroundColor = UIColor(hex: "#EDEDED")
        return tv
    }()

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(hex: "#EDEDED")
        title = "发现"
        setupTableView()
    }

    private func setupTableView() {
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

extension DiscoverViewController: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        sectionItems.count
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sectionItems[section].count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "DiscoverCell", for: indexPath)
        let item = sectionItems[indexPath.section][indexPath.row]

        var config = cell.defaultContentConfiguration()
        let iconImage = UIImage(systemName: item.icon)?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 20))
        config.image = iconImage
        config.imageProperties.tintColor = item.iconColor
        config.text = item.title
        config.textProperties.font = .systemFont(ofSize: 16)
        cell.contentConfiguration = config
        cell.accessoryType = .disclosureIndicator
        return cell
    }
}

extension DiscoverViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let item = sectionItems[indexPath.section][indexPath.row]
        Router.shared.push(item.route)
    }
}
