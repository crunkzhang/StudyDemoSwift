import UIKit
import SnapKit

public class ChatListCell: UITableViewCell {
    public static let reuseID = "ChatListCell"

    private static let imageCache = NSCache<NSString, UIImage>()

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.layer.cornerRadius = 6
        iv.clipsToBounds = true
        iv.contentMode = .scaleAspectFill
        iv.backgroundColor = UIColor(white: 0.93, alpha: 1)
        return iv
    }()

    private let avatarFallbackView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 6
        v.clipsToBounds = true
        return v
    }()

    private let initialLabel: UILabel = {
        let l = UILabel()
        l.textColor = .white
        l.font = .systemFont(ofSize: 19, weight: .semibold)
        l.textAlignment = .center
        return l
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
        s.spacing = 7
        return s
    }()

    private var representedAvatarURL: String?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func prepareForReuse() {
        super.prepareForReuse()
        representedAvatarURL = nil
        avatarImageView.image = nil
        avatarFallbackView.isHidden = false
        badgeLabel.isHidden = true
    }

    private func setupViews() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .white

        avatarFallbackView.addSubview(initialLabel)
        textStack.addArrangedSubview(nameLabel)
        textStack.addArrangedSubview(messageLabel)
        rightStack.addArrangedSubview(timeLabel)
        rightStack.addArrangedSubview(badgeLabel)

        contentView.addSubview(avatarImageView)
        contentView.addSubview(avatarFallbackView)
        contentView.addSubview(textStack)
        contentView.addSubview(rightStack)

        avatarImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(14)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(48)
        }

        avatarFallbackView.snp.makeConstraints { make in
            make.edges.equalTo(avatarImageView)
        }

        initialLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        textStack.snp.makeConstraints { make in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(12)
            make.centerY.equalToSuperview()
            make.trailing.lessThanOrEqualTo(rightStack.snp.leading).offset(-8)
        }

        rightStack.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-14)
            make.centerY.equalToSuperview()
            make.width.equalTo(64)
        }

        badgeLabel.snp.makeConstraints { make in
            make.height.equalTo(18)
            make.width.equalTo(18)
        }
    }

    public func configure(with chat: ChatConversation) {
        representedAvatarURL = chat.avatarURL
        avatarImageView.image = nil
        avatarFallbackView.isHidden = false

        avatarFallbackView.backgroundColor = UIColor(
            red: CGFloat((chat.avatarColor >> 16) & 0xFF) / 255,
            green: CGFloat((chat.avatarColor >> 8) & 0xFF) / 255,
            blue: CGFloat(chat.avatarColor & 0xFF) / 255,
            alpha: 1
        )

        initialLabel.text = chat.avatarInitial
        nameLabel.text = chat.contactName
        messageLabel.text = chat.lastMessage
        timeLabel.text = chat.formattedTime

        loadAvatar(from: chat.avatarURL)

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

    private func loadAvatar(from urlString: String) {
        if let cachedImage = Self.imageCache.object(forKey: urlString as NSString) {
            avatarImageView.image = cachedImage
            avatarFallbackView.isHidden = true
            return
        }

        guard let url = URL(string: urlString) else {
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard
                let self,
                let data,
                let image = UIImage(data: data)
            else {
                return
            }

            Self.imageCache.setObject(image, forKey: urlString as NSString)
            DispatchQueue.main.async {
                guard self.representedAvatarURL == urlString else {
                    return
                }
                self.avatarImageView.image = image
                self.avatarFallbackView.isHidden = true
            }
        }.resume()
    }
}
