import UIKit
import WeChatUI
import SnapKit
import ExtensionKit
import WeChatRouter

public class MeViewController: BaseViewController {
    fileprivate struct MeItem {
        let icon: String
        let iconColor: UIColor
        let title: String
    }

    private let sectionItems: [[MeItem]] = [
        [
            MeItem(icon: "creditcard.fill", iconColor: UIColor(hex: "#576B95"), title: "服务"),
        ],
        [
            MeItem(icon: "star.fill", iconColor: UIColor(hex: "#FA9D3B"), title: "收藏"),
            MeItem(icon: "photo.on.rectangle.fill", iconColor: UIColor(hex: "#07C160"), title: "朋友圈"),
            MeItem(icon: "menucard.fill", iconColor: UIColor(hex: "#576B95"), title: "卡包"),
            MeItem(icon: "face.smiling.fill", iconColor: UIColor(hex: "#FA9D3B"), title: "表情"),
        ],
        [
            MeItem(icon: "gearshape.fill", iconColor: UIColor(hex: "#576B95"), title: "设置"),
        ],
    ]

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.backgroundColor = UIColor(hex: "#F2F3F5")
        tv.dataSource = self
        tv.delegate = self
        tv.separatorStyle = .singleLine
        tv.separatorColor = UIColor(hex: "#E7E8EB")
        tv.rowHeight = 62
        tv.sectionHeaderHeight = 14
        tv.sectionFooterHeight = 0.01
        tv.contentInset = UIEdgeInsets(top: 4, left: 0, bottom: 24, right: 0)
        tv.register(MeMenuCell.self, forCellReuseIdentifier: MeMenuCell.reuseIdentifier)
        return tv
    }()

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(hex: "#F2F3F5")
        setupTableView()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    private func setupTableView() {
        tableView.tableHeaderView = createProfileHeader()
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func createProfileHeader() -> UIView {
        let header = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 164))
        header.backgroundColor = UIColor(hex: "#F2F3F5")

        let panel = UIView()
        panel.backgroundColor = .white
        panel.layer.cornerRadius = 26
        panel.layer.cornerCurve = .continuous

        let avatarView = UIView()
        avatarView.backgroundColor = UIColor(hex: "#07C160")
        avatarView.layer.cornerRadius = 18
        avatarView.layer.cornerCurve = .continuous
        avatarView.clipsToBounds = true

        let avatarLabel = UILabel()
        avatarLabel.text = "我"
        avatarLabel.textColor = .white
        avatarLabel.font = .systemFont(ofSize: 30, weight: .bold)
        avatarLabel.textAlignment = .center

        let nameLabel = UILabel()
        nameLabel.text = "用户"
        nameLabel.font = .systemFont(ofSize: 26, weight: .bold)
        nameLabel.textColor = UIColor(hex: "#101114")

        let idLabel = UILabel()
        idLabel.text = "微信号 wxid_demo"
        idLabel.font = .systemFont(ofSize: 14, weight: .medium)
        idLabel.textColor = UIColor(hex: "#6F7682")

        let statusPill = UILabel()
        statusPill.text = "状态 · 今天也在认真生活"
        statusPill.font = .systemFont(ofSize: 12, weight: .semibold)
        statusPill.textColor = UIColor(hex: "#526168")
        statusPill.backgroundColor = UIColor(hex: "#F5F7F8")
        statusPill.layer.cornerRadius = 13
        statusPill.layer.cornerCurve = .continuous
        statusPill.clipsToBounds = true
        statusPill.textAlignment = .center

        let qrWrap = UIView()
        qrWrap.backgroundColor = UIColor(hex: "#F5F7F8")
        qrWrap.layer.cornerRadius = 18
        qrWrap.layer.cornerCurve = .continuous

        let qrIcon = UIImageView(image: UIImage(systemName: "qrcode"))
        qrIcon.tintColor = UIColor(hex: "#5C6673")
        qrIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)

        let arrow = UIImageView(image: UIImage(systemName: "chevron.right"))
        arrow.tintColor = UIColor(hex: "#C2C6CC")
        arrow.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)

        header.addSubview(panel)
        panel.addSubview(avatarView)
        avatarView.addSubview(avatarLabel)
        panel.addSubview(nameLabel)
        panel.addSubview(idLabel)
        panel.addSubview(statusPill)
        panel.addSubview(qrWrap)
        qrWrap.addSubview(qrIcon)
        panel.addSubview(arrow)

        panel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.leading.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-12)
            make.bottom.equalToSuperview().offset(-8)
        }

        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(18)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(76)
        }

        avatarLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(16)
            make.top.equalToSuperview().offset(26)
        }

        idLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.top.equalTo(nameLabel.snp.bottom).offset(6)
        }

        statusPill.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.top.equalTo(idLabel.snp.bottom).offset(10)
            make.height.equalTo(26)
        }

        qrWrap.snp.makeConstraints { make in
            make.trailing.equalTo(arrow.snp.leading).offset(-10)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(36)
        }

        qrIcon.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        arrow.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-18)
            make.centerY.equalToSuperview()
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
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: MeMenuCell.reuseIdentifier,
            for: indexPath
        ) as? MeMenuCell else {
            return UITableViewCell()
        }

        let item = sectionItems[indexPath.section][indexPath.row]
        cell.configure(with: item)
        return cell
    }
}

extension MeViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        let item = sectionItems[indexPath.section][indexPath.row]
        if item.title == "设置" {
            Router.shared.push(Routes.settings)
        }
    }

    public func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        cell.backgroundColor = .white
    }
}

private final class MeMenuCell: UITableViewCell {
    static let reuseIdentifier = "MeMenuCell"

    private let iconWrap = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let customArrow = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        contentView.frame = contentView.frame.inset(by: UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0))
    }

    func configure(with item: MeViewController.MeItem) {
        let image = UIImage(systemName: item.icon)?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold))
        iconView.image = image
        iconView.tintColor = item.iconColor
        iconWrap.backgroundColor = item.iconColor.withAlphaComponent(0.12)
        titleLabel.text = item.title
    }

    private func setupUI() {
        backgroundColor = .white
        selectionStyle = .none
        accessoryType = .none
        separatorInset = UIEdgeInsets(top: 0, left: 54, bottom: 0, right: 0)

        iconWrap.layer.cornerRadius = 11
        iconWrap.layer.cornerCurve = .continuous

        titleLabel.font = .systemFont(ofSize: 17, weight: .medium)
        titleLabel.textColor = UIColor(hex: "#111317")

        customArrow.image = UIImage(systemName: "chevron.right")
        customArrow.tintColor = UIColor(hex: "#C7CBD2")
        customArrow.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)

        contentView.addSubview(iconWrap)
        iconWrap.addSubview(iconView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(customArrow)

        iconWrap.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(18)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(30)
        }

        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconWrap.snp.trailing).offset(14)
            make.centerY.equalToSuperview()
        }

        customArrow.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-18)
            make.centerY.equalToSuperview()
        }
    }
}
