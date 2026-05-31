import UIKit
import SnapKit
import ExtensionKit

/// 通用菜单 cell:icon(SF Symbol)+ 圆角底色 + 标题 + 可选 badge/右文 + chevron。
/// 由 MeViewController 原来的 MeMenuCell 泛化而来。
final class DSLMenuCell: UITableViewCell {
    static let reuseIdentifier = "DSLMenuCell"

    private let iconWrap = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let rightLabel = UILabel()
    private let badgeLabel = PaddingLabel()
    private let chevron = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(with node: DSLNode) {
        let iconName = node.string("icon") ?? "circle"
        let color = UIColor(hex: node.string("iconColor") ?? "#576B95")
        iconView.image = UIImage(systemName: iconName)?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold))
        iconView.tintColor = color
        iconWrap.backgroundColor = color.withAlphaComponent(0.12)
        titleLabel.text = node.string("title")

        if let right = node.string("rightText"), !right.isEmpty {
            rightLabel.text = right
            rightLabel.isHidden = false
        } else {
            rightLabel.isHidden = true
        }

        if let badge = node.string("badge"), !badge.isEmpty {
            badgeLabel.text = badge
            badgeLabel.isHidden = false
        } else {
            badgeLabel.isHidden = true
        }
    }

    private func setupUI() {
        backgroundColor = .white
        selectionStyle = .default
        separatorInset = UIEdgeInsets(top: 0, left: 54, bottom: 0, right: 0)

        iconWrap.layer.cornerRadius = 11
        iconWrap.layer.cornerCurve = .continuous

        titleLabel.font = .systemFont(ofSize: 17, weight: .medium)
        titleLabel.textColor = UIColor(hex: "#111317")

        rightLabel.font = .systemFont(ofSize: 14, weight: .regular)
        rightLabel.textColor = UIColor(hex: "#8A9099")

        badgeLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = UIColor(hex: "#FA5151")
        badgeLabel.layer.cornerRadius = 9
        badgeLabel.layer.masksToBounds = true
        badgeLabel.textAlignment = .center

        chevron.image = UIImage(systemName: "chevron.right")
        chevron.tintColor = UIColor(hex: "#C7CBD2")
        chevron.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)

        contentView.addSubview(iconWrap)
        iconWrap.addSubview(iconView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(chevron)
        contentView.addSubview(rightLabel)
        contentView.addSubview(badgeLabel)

        iconWrap.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(18)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(30)
        }
        iconView.snp.makeConstraints { $0.center.equalToSuperview() }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconWrap.snp.trailing).offset(14)
            make.centerY.equalToSuperview()
        }
        chevron.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-18)
            make.centerY.equalToSuperview()
        }
        badgeLabel.snp.makeConstraints { make in
            make.trailing.equalTo(chevron.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
            make.height.equalTo(18)
            make.width.greaterThanOrEqualTo(18)
        }
        rightLabel.snp.makeConstraints { make in
            make.trailing.equalTo(chevron.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
        }
    }
}

/// 带内边距的 label(badge 用)
private final class PaddingLabel: UILabel {
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + 12, height: s.height)
    }
}
