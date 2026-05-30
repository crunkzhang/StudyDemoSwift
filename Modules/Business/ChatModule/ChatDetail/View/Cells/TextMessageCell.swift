import UIKit
import SnapKit

public final class TextMessageCell: BaseMessageCell {
    public static let reuseID = "TextMessageCell"

    private let textBubbleLabel: UILabel = {
        let l = UILabel()
        l.numberOfLines = 0
        l.font = .systemFont(ofSize: 16)
        l.textColor = UIColor(white: 0.1, alpha: 1)
        return l
    }()

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        bubbleView.addSubview(textBubbleLabel)
        textBubbleLabel.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    public func configure(_ m: MessageCellModel) {
        textBubbleLabel.text = m.text
        bubbleView.backgroundColor = m.isFromMe
            ? UIColor(red: 0.58, green: 0.93, blue: 0.45, alpha: 1)  // 微信绿
            : UIColor(white: 0.95, alpha: 1)

        bubbleView.snp.remakeConstraints { make in
            make.top.bottom.equalToSuperview().inset(6)
            make.width.lessThanOrEqualTo(260)
            if m.isFromMe {
                make.trailing.equalToSuperview().offset(-14)
            } else {
                make.leading.equalToSuperview().offset(14)
            }
        }

        statusIndicator.snp.remakeConstraints { make in
            make.centerY.equalTo(bubbleView)
            if m.isFromMe {
                make.trailing.equalTo(bubbleView.snp.leading).offset(-6)
            } else {
                make.leading.equalTo(bubbleView.snp.trailing).offset(6)
            }
            make.width.height.equalTo(20)
        }

        failedIcon.snp.remakeConstraints { make in
            make.center.equalTo(statusIndicator)
            make.width.height.equalTo(22)
        }

        applyStatus(m.status, isFromMe: m.isFromMe)
    }
}
