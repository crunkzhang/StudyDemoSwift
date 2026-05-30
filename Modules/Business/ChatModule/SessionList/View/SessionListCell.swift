import UIKit
import SnapKit
import SDWebImage

public class SessionListCell: UITableViewCell {
    public static let reuseID = "SessionListCell"

    // MARK: - Avatar:fallback 色块+首字 在下,SDWebImage 加载的 imageView 在上

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

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.layer.cornerRadius = 6
        iv.clipsToBounds = true
        iv.contentMode = .scaleAspectFill
        iv.backgroundColor = .clear
        iv.isHidden = true
        return iv
    }()

    // MARK: - 文字 + 时间 + 未读

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

    public override func prepareForReuse() {
        super.prepareForReuse()
        // 取消正在进行的 SDWebImage 加载,防止 cell 复用串图
        avatarImageView.sd_cancelCurrentImageLoad()
        avatarImageView.image = nil
        avatarImageView.isHidden = true
    }

    private func setup() {
        selectionStyle = .default
        contentView.backgroundColor = .white

        contentView.addSubview(avatarFallbackView)
        avatarFallbackView.addSubview(initialLabel)
        contentView.addSubview(avatarImageView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(messageLabel)
        contentView.addSubview(timeLabel)
        contentView.addSubview(badgeLabel)

        avatarFallbackView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(14)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(48)
        }
        avatarImageView.snp.makeConstraints { make in
            make.edges.equalTo(avatarFallbackView)
        }
        initialLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarFallbackView.snp.trailing).offset(12)
            make.top.equalTo(avatarFallbackView)
            make.trailing.lessThanOrEqualTo(timeLabel.snp.leading).offset(-8)
        }
        messageLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.bottom.equalTo(avatarFallbackView)
            make.trailing.lessThanOrEqualTo(badgeLabel.snp.leading).offset(-8)
        }
        timeLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-14)
            make.top.equalTo(avatarFallbackView)
        }
        badgeLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-14)
            make.bottom.equalTo(avatarFallbackView)
            make.height.equalTo(18)
            make.width.greaterThanOrEqualTo(18)
        }
    }

    public func configure(_ m: SessionCellModel) {
        // fallback 色块 + 首字
        initialLabel.text = m.avatarInitial
        avatarFallbackView.backgroundColor = UIColor(
            red:   CGFloat((m.avatarColor >> 16) & 0xFF) / 255,
            green: CGFloat((m.avatarColor >> 8) & 0xFF) / 255,
            blue:  CGFloat( m.avatarColor       & 0xFF) / 255,
            alpha: 1
        )

        // SDWebImage 异步加载(内部内存/磁盘缓存 + 防串图 + 自动取消)
        if let urlString = m.avatarURL, let url = URL(string: urlString) {
            avatarImageView.sd_setImage(
                with: url,
                placeholderImage: nil,
                options: [.retryFailed, .scaleDownLargeImages]
            ) { [weak self] image, error, _, _ in
                // 加载成功才显示 imageView,否则继续露出 fallback 色块
                self?.avatarImageView.isHidden = (image == nil || error != nil)
            }
        } else {
            avatarImageView.isHidden = true
        }

        // 文字内容
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
