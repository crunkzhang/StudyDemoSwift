import UIKit
import SnapKit
import ExtensionKit

public class MeViewController: UIViewController {
    private struct MeItem {
        let icon: String
        let iconColor: UIColor
        let title: String
    }

    private let sectionItems: [[MeItem]] = [
        [
            MeItem(icon: "creditcard", iconColor: UIColor(hex: "#576B95"), title: "服务"),
        ],
        [
            MeItem(icon: "star", iconColor: UIColor(hex: "#FA9D3B"), title: "收藏"),
            MeItem(icon: "photo.on.rectangle", iconColor: UIColor(hex: "#07C160"), title: "朋友圈"),
            MeItem(icon: "menucard", iconColor: UIColor(hex: "#576B95"), title: "卡包"),
            MeItem(icon: "face.smiling", iconColor: UIColor(hex: "#FA9D3B"), title: "表情"),
        ],
        [
            MeItem(icon: "gearshape", iconColor: UIColor(hex: "#576B95"), title: "设置"),
        ],
    ]

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.dataSource = self
        tv.delegate = self
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "MeCell")
        tv.rowHeight = 52
        tv.backgroundColor = UIColor(hex: "#EDEDED")
        return tv
    }()

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(hex: "#EDEDED")
        title = "我"
        setupTableView()
    }

    private func setupTableView() {
        tableView.tableHeaderView = createProfileHeader()
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func createProfileHeader() -> UIView {
        let header = UIView(frame: CGRect(x: 0, y: 0, width: 0, height: 100))
        header.backgroundColor = .white

        // 头像
        let avatarView = UIView()
        avatarView.backgroundColor = UIColor(hex: "#07C160")
        avatarView.layer.cornerRadius = 8
        avatarView.clipsToBounds = true

        let avatarLabel = UILabel()
        avatarLabel.text = "我"
        avatarLabel.textColor = .white
        avatarLabel.font = .systemFont(ofSize: 24, weight: .bold)
        avatarLabel.textAlignment = .center
        avatarView.addSubview(avatarLabel)

        // 名字
        let nameLabel = UILabel()
        nameLabel.text = "用户"
        nameLabel.font = .systemFont(ofSize: 18, weight: .medium)

        // 微信号
        let idLabel = UILabel()
        idLabel.text = "微信号：wxid_demo"
        idLabel.font = .systemFont(ofSize: 13)
        idLabel.textColor = .gray

        // 二维码图标
        let qrIcon = UIImageView(image: UIImage(systemName: "qrcode"))
        qrIcon.tintColor = .gray

        let arrow = UIImageView(image: UIImage(systemName: "chevron.right"))
        arrow.tintColor = UIColor.lightGray

        header.addSubview(avatarView)
        header.addSubview(nameLabel)
        header.addSubview(idLabel)
        header.addSubview(qrIcon)
        header.addSubview(arrow)

        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(60)
        }

        avatarLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(14)
            make.top.equalTo(avatarView).offset(6)
        }

        idLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom).offset(8)
        }

        arrow.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
        }

        qrIcon.snp.makeConstraints { make in
            make.trailing.equalTo(arrow.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(18)
        }

        return header
    }
}

extension MeViewController: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        sectionItems.count
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sectionItems[section].count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "MeCell", for: indexPath)
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

extension MeViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
