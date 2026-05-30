import UIKit
import SnapKit

public class SessionListCell: UITableViewCell {
    public static let reuseID = "SessionListCell"

    private let avatarView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 6
        v.backgroundColor = UIColor(white: 0.9, alpha: 1)
        v.clipsToBounds = true
        return v
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 17, weight: .medium)
        l.textColor = UIColor(white: 0.08, alpha: 1)
        return l
    }()

    private let messageLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14)
        l.textColor = UIColor(white: 0.47, alpha: 1)
        l.lineBreakMode = .byTruncatingTail
        return l
    }()

    private let timeLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12)
        l.textColor = UIColor(white: 0.67, alpha: 1)
        l.textAlignment = .right
        return l
    }()

    private let badgeLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11, weight: .semibold)
        l.textColor = .white
        l.backgroundColor = UIColor(red: 1, green: 0.23, blue: 0.19, alpha: 1)
        l.textAlignment = .center
        l.clipsToBounds = true
        l.isHidden = true
        l.layer.cornerRadius = 9
        return l
    }()

    private let pinnedBackground = UIColor(white: 0.96, alpha: 1)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        selectionStyle = .default
        contentView.backgroundColor = .white
        contentView.addSubview(avatarView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(messageLabel)
        contentView.addSubview(timeLabel)
        contentView.addSubview(badgeLabel)

        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(14)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(48)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(12)
            make.top.equalTo(avatarView)
            make.trailing.lessThanOrEqualTo(timeLabel.snp.leading).offset(-8)
        }
        messageLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.bottom.equalTo(avatarView)
            make.trailing.lessThanOrEqualTo(badgeLabel.snp.leading).offset(-8)
        }
        timeLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-14)
            make.top.equalTo(avatarView)
        }
        badgeLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-14)
            make.bottom.equalTo(avatarView)
            make.height.equalTo(18)
            make.width.greaterThanOrEqualTo(18)
        }
    }

    public func configure(_ m: SessionCellModel) {
        nameLabel.text = m.contactName
        messageLabel.text = m.lastMsgPreview
        timeLabel.text = m.formattedTime
        if m.unreadCount > 0 {
            badgeLabel.isHidden = false
            badgeLabel.text = m.unreadCount > 99 ? "99+" : "\(m.unreadCount)"
        } else {
            badgeLabel.isHidden = true
        }
        contentView.backgroundColor = m.isPinned ? pinnedBackground : .white
    }
}
