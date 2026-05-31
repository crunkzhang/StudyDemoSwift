import UIKit
import SnapKit
import ExtensionKit

/// 「我的」页头部组件:头像 + 昵称 + 微信号 + 状态 pill + 二维码箭头。
/// 静态结构来自 schema;头像图片/状态文案的 live 数据由 MeViewController 异步回填。
public final class DSLProfileHeaderView: UIView {

    public static let preferredHeight: CGFloat = 164

    private let avatarView = UIView()
    private let avatarImageView = UIImageView()
    private let avatarLabel = UILabel()
    private let nameLabel = UILabel()
    private let idLabel = UILabel()
    private let statusPill = UILabel()

    public var onTap: (() -> Void)?

    public init(node: DSLNode) {
        super.init(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: Self.preferredHeight))
        setup(node: node)
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup(node: DSLNode) {
        backgroundColor = UIColor(hex: node.string("background") ?? "#F2F3F5")

        let panel = UIView()
        panel.backgroundColor = .white
        panel.layer.cornerRadius = 26
        panel.layer.cornerCurve = .continuous

        avatarView.backgroundColor = UIColor(hex: node.string("avatarColor") ?? "#07C160")
        avatarView.layer.cornerRadius = 18
        avatarView.layer.cornerCurve = .continuous
        avatarView.clipsToBounds = true

        avatarImageView.contentMode = .scaleAspectFill
        avatarImageView.clipsToBounds = true

        avatarLabel.text = node.string("avatarText") ?? "我"
        avatarLabel.textColor = .white
        avatarLabel.font = .systemFont(ofSize: 30, weight: .bold)
        avatarLabel.textAlignment = .center

        nameLabel.text = node.string("name") ?? "用户"
        nameLabel.font = .systemFont(ofSize: 26, weight: .bold)
        nameLabel.textColor = UIColor(hex: "#101114")

        idLabel.text = node.string("wxid") ?? "微信号 wxid_demo"
        idLabel.font = .systemFont(ofSize: 14, weight: .medium)
        idLabel.textColor = UIColor(hex: "#6F7682")

        statusPill.text = node.string("status") ?? "状态"
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

        addSubview(panel)
        panel.addSubview(avatarView)
        avatarView.addSubview(avatarImageView)
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
        avatarLabel.snp.makeConstraints { $0.center.equalToSuperview() }
        avatarImageView.snp.makeConstraints { $0.edges.equalToSuperview() }
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
        qrIcon.snp.makeConstraints { $0.center.equalToSuperview() }
        arrow.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-18)
            make.centerY.equalToSuperview()
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        panel.addGestureRecognizer(tap)
        panel.isUserInteractionEnabled = true
    }

    @objc private func handleTap() { onTap?() }

    // MARK: - live 数据回填

    public func updateAvatar(_ image: UIImage?) {
        if let image {
            avatarImageView.image = image
            avatarLabel.isHidden = true
        } else {
            avatarImageView.image = nil
            avatarLabel.isHidden = false
        }
    }

    public func updateStatus(_ text: String?) {
        if let text, !text.isEmpty { statusPill.text = text }
    }
}
