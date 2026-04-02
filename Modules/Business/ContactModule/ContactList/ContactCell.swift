import UIKit
import SnapKit
import ExtensionKit

public class ContactCell: UITableViewCell {
    public static let reuseID = "ContactCell"

    private let avatarView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 12
        v.layer.cornerCurve = .continuous
        v.clipsToBounds = true
        return v
    }()

    private let initialLabel: UILabel = {
        let l = UILabel()
        l.textColor = .white
        l.font = .systemFont(ofSize: 16, weight: .semibold)
        l.textAlignment = .center
        return l
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 17, weight: .medium)
        l.textColor = UIColor(hex: "#14171B")
        return l
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        selectionStyle = .none
        backgroundColor = .white

        avatarView.addSubview(initialLabel)
        contentView.addSubview(avatarView)
        contentView.addSubview(nameLabel)

        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(42)
        }

        initialLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(14)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview().offset(-14)
        }
    }

    public func configure(with contact: Contact) {
        avatarView.backgroundColor = UIColor(
            red: CGFloat((contact.avatarColor >> 16) & 0xFF) / 255,
            green: CGFloat((contact.avatarColor >> 8) & 0xFF) / 255,
            blue: CGFloat(contact.avatarColor & 0xFF) / 255,
            alpha: 1
        )
        initialLabel.text = contact.initial
        nameLabel.text = contact.name
    }
}
