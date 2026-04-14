import UIKit
import SnapKit
import ExtensionKit

final class ContactDetailHeaderView: UIView {
    let avatarView = UIImageView()
    let nameLabel = UILabel()
    let remarkLabel = UILabel()
    let wxidLabel = UILabel()
    let regionLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        avatarView.layer.cornerRadius = 6
        avatarView.layer.masksToBounds = true
        avatarView.backgroundColor = UIColor(hex: "#07C160")
        avatarView.layer.borderWidth = 1.0 / UIScreen.main.scale
        avatarView.layer.borderColor = UIColor.black.withAlphaComponent(0.04).cgColor

        nameLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        nameLabel.textColor = UIColor(hex: "#191919")
        remarkLabel.font = .systemFont(ofSize: 15)
        remarkLabel.textColor = UIColor(hex: "#888888")
        wxidLabel.font = .systemFont(ofSize: 13)
        wxidLabel.textColor = UIColor(hex: "#888888")
        regionLabel.font = .systemFont(ofSize: 13)
        regionLabel.textColor = UIColor(hex: "#888888")

        [avatarView, nameLabel, remarkLabel, wxidLabel, regionLabel].forEach { addSubview($0) }

        avatarView.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(16)
            $0.top.equalToSuperview().offset(20)
            $0.bottom.equalToSuperview().offset(-20)
            $0.size.equalTo(64)
        }
        nameLabel.snp.makeConstraints {
            $0.leading.equalTo(avatarView.snp.trailing).offset(14)
            $0.top.equalTo(avatarView).offset(2)
            $0.trailing.lessThanOrEqualToSuperview().offset(-16)
        }
        remarkLabel.snp.makeConstraints {
            $0.leading.equalTo(nameLabel)
            $0.top.equalTo(nameLabel.snp.bottom).offset(4)
            $0.trailing.lessThanOrEqualToSuperview().offset(-16)
        }
        wxidLabel.snp.makeConstraints {
            $0.leading.equalTo(nameLabel)
            $0.top.equalTo(remarkLabel.snp.bottom).offset(4)
        }
        regionLabel.snp.makeConstraints {
            $0.leading.equalTo(wxidLabel.snp.trailing).offset(10)
            $0.centerY.equalTo(wxidLabel)
        }

        let separator = UIView()
        separator.backgroundColor = UIColor(hex: "#E5E5E5")
        addSubview(separator)
        separator.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.height.equalTo(1.0 / UIScreen.main.scale)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(name: String, remark: String?, wxid: String, region: String?) {
        nameLabel.text = name
        remarkLabel.text = remark
        remarkLabel.isHidden = (remark?.isEmpty ?? true)
        wxidLabel.text = "微信号: \(wxid)"
        regionLabel.text = region.map { "地区: \($0)" }

        let initial = String(name.prefix(1))
        avatarView.image = UIImage.fromInitial(initial, size: CGSize(width: 128, height: 128))
    }
}

private extension UIImage {
    static func fromInitial(_ text: String, size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, true, 0)
        defer { UIGraphicsEndImageContext() }
        UIColor(hex: "#07C160").setFill()
        UIRectFill(CGRect(origin: .zero, size: size))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size.width * 0.42, weight: .semibold),
            .foregroundColor: UIColor.white,
        ]
        let s = NSString(string: text)
        let bounds = s.size(withAttributes: attrs)
        s.draw(at: CGPoint(x: (size.width - bounds.width) / 2, y: (size.height - bounds.height) / 2), withAttributes: attrs)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
