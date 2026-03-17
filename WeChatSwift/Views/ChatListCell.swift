import UIKit
import SnapKit

class ChatListCell: UITableViewCell {
    static let reuseID = "ChatListCell"

    private let avatarView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 4
        v.clipsToBounds = true
        return v
    }()

    private let initialLabel: UILabel = {
        let l = UILabel()
        l.textColor = .white
        l.font = .systemFont(ofSize: 18, weight: .semibold)
        l.textAlignment = .center
        return l
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 16, weight: .medium)
        l.textColor = .black
        return l
    }()

    private let messageLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14)
        l.textColor = .gray
        l.lineBreakMode = .byTruncatingTail
        return l
    }()

    private let timeLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12)
        l.textColor = .lightGray
        l.textAlignment = .right
        return l
    }()

    private let badgeLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11, weight: .medium)
        l.textColor = .white
        l.backgroundColor = UIColor(red: 1, green: 0.23, blue: 0.19, alpha: 1)
        l.textAlignment = .center
        l.clipsToBounds = true
        l.isHidden = true
        return l
    }()

    private let textStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 4
        return s
    }()

    private let rightStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.alignment = .trailing
        s.spacing = 6
        return s
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
        textStack.addArrangedSubview(nameLabel)
        textStack.addArrangedSubview(messageLabel)
        rightStack.addArrangedSubview(timeLabel)
        rightStack.addArrangedSubview(badgeLabel)

        contentView.addSubview(avatarView)
        contentView.addSubview(textStack)
        contentView.addSubview(rightStack)

        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(40)
        }

        initialLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        textStack.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(10)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(rightStack.snp.leading).offset(-8)
        }

        rightStack.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
            make.width.equalTo(60)
        }

        badgeLabel.snp.makeConstraints { make in
            make.height.equalTo(18)
            make.width.equalTo(18)
        }
    }

    func configure(with chat: ChatConversation) {
        avatarView.backgroundColor = UIColor(
            red: CGFloat((chat.avatarColor >> 16) & 0xFF) / 255,
            green: CGFloat((chat.avatarColor >> 8) & 0xFF) / 255,
            blue: CGFloat(chat.avatarColor & 0xFF) / 255,
            alpha: 1
        )
        initialLabel.text = chat.avatarInitial
        nameLabel.text = chat.contactName
        messageLabel.text = chat.lastMessage
        timeLabel.text = chat.formattedTime

        if chat.unreadCount > 0 {
            badgeLabel.isHidden = false
            let text = chat.unreadCount > 99 ? "99+" : "\(chat.unreadCount)"
            badgeLabel.text = text
            let width = max(18, CGFloat(text.count) * 8 + 8)
            badgeLabel.snp.updateConstraints { make in
                make.width.equalTo(width)
            }
            badgeLabel.layer.cornerRadius = 9
        } else {
            badgeLabel.isHidden = true
        }
    }
}
