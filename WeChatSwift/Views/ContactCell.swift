import UIKit
import SnapKit

class ContactCell: UITableViewCell {
    static let reuseID = "ContactCell"

    private let avatarView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 4
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
        l.font = .systemFont(ofSize: 16)
        l.textColor = .black
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
        avatarView.addSubview(initialLabel)
        contentView.addSubview(avatarView)
        contentView.addSubview(nameLabel)

        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(36)
        }

        initialLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(10)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualToSuperview().offset(-12)
        }
    }

    func configure(with contact: Contact) {
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
