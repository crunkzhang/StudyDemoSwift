import UIKit
import SnapKit
import ExtensionKit

// MARK: - Banner(渐变卡:标题 + 副标题,支持 {{}} 绑定)

final class DSLBannerCell: UICollectionViewCell {
    static let reuseId = "DSLBannerCell"
    private let gradient = CAGradientLayer()
    private let titleLabel = UILabel()
    private let subLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.layer.cornerRadius = 14
        contentView.layer.cornerCurve = .continuous
        contentView.clipsToBounds = true
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        contentView.layer.addSublayer(gradient)
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .white
        subLabel.font = .systemFont(ofSize: 13, weight: .medium)
        subLabel.textColor = UIColor.white.withAlphaComponent(0.85)
        subLabel.numberOfLines = 2
        contentView.addSubview(titleLabel)
        contentView.addSubview(subLabel)
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(18)
            make.top.equalToSuperview().offset(22)
            make.trailing.lessThanOrEqualToSuperview().offset(-18)
        }
        subLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(6)
            make.trailing.lessThanOrEqualToSuperview().offset(-18)
        }
    }
    required init?(coder: NSCoder) { fatalError() }
    override func layoutSubviews() { super.layoutSubviews(); gradient.frame = contentView.bounds }

    func configure(_ node: DSLNode, _ ctx: DSLContext) {
        titleLabel.text = DSLTemplate.resolve(node.string("title"), ctx)
        subLabel.text = DSLTemplate.resolve(node.string("subtitle"), ctx)
        // bg: 单色 hex 或 gradient: [hex,hex]
        if let arr = node.props["gradient"]?.arrayValue, arr.count >= 2 {
            gradient.colors = [UIColor(hex: arr[0].stringValue ?? "#07C160").cgColor,
                               UIColor(hex: arr[1].stringValue ?? "#048A45").cgColor]
        } else {
            let c = UIColor(hex: node.string("bg") ?? "#07C160")
            gradient.colors = [c.cgColor, c.withAlphaComponent(0.78).cgColor]
        }
    }
}

// MARK: - Grid item(图标 + 标题,九宫格入口)

final class DSLGridCell: UICollectionViewCell {
    static let reuseId = "DSLGridCell"
    private let iconWrap = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        iconWrap.layer.cornerRadius = 14
        iconWrap.layer.cornerCurve = .continuous
        titleLabel.font = .systemFont(ofSize: 12, weight: .medium)
        titleLabel.textColor = UIColor(hex: "#333333")
        titleLabel.textAlignment = .center
        contentView.addSubview(iconWrap)
        iconWrap.addSubview(iconView)
        contentView.addSubview(titleLabel)
        iconWrap.snp.makeConstraints { make in
            make.top.centerX.equalToSuperview()
            make.width.height.equalTo(48)
        }
        iconView.snp.makeConstraints { $0.center.equalToSuperview() }
        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconWrap.snp.bottom).offset(6)
            make.leading.trailing.equalToSuperview()
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(_ node: DSLNode, _ ctx: DSLContext) {
        let color = UIColor(hex: node.string("iconColor") ?? "#07C160")
        iconView.image = UIImage(systemName: node.string("icon") ?? "circle")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold))
        iconView.tintColor = color
        iconWrap.backgroundColor = color.withAlphaComponent(0.12)
        titleLabel.text = DSLTemplate.resolve(node.string("title"), ctx)
    }
}

// MARK: - Text(标题 + 副标题段落)

final class DSLTextCell: UICollectionViewCell {
    static let reuseId = "DSLTextCell"
    private let titleLabel = UILabel()
    private let subLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        titleLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        titleLabel.textColor = UIColor(hex: "#1A1A1A")
        subLabel.font = .systemFont(ofSize: 13)
        subLabel.textColor = UIColor(hex: "#8A9099")
        subLabel.numberOfLines = 0
        let stack = UIStackView(arrangedSubviews: [titleLabel, subLabel])
        stack.axis = .vertical
        stack.spacing = 4
        contentView.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    func configure(_ node: DSLNode, _ ctx: DSLContext) {
        titleLabel.text = DSLTemplate.resolve(node.string("title"), ctx)
        let sub = DSLTemplate.resolve(node.string("subtitle"), ctx)
        subLabel.text = sub
        subLabel.isHidden = (sub ?? "").isEmpty
    }
}
