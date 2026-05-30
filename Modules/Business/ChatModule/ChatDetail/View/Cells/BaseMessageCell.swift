import UIKit
import SnapKit
import WCIMSDK

public class BaseMessageCell: UITableViewCell {

    let bubbleView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 8
        return v
    }()

    let statusIndicator: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .medium)
        s.hidesWhenStopped = true
        return s
    }()

    let failedIcon: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "exclamationmark.circle.fill"))
        iv.tintColor = .systemRed
        iv.isHidden = true
        return iv
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.backgroundColor = .white
        contentView.addSubview(bubbleView)
        contentView.addSubview(statusIndicator)
        contentView.addSubview(failedIcon)
        selectionStyle = .none
    }
    required init?(coder: NSCoder) { fatalError() }

    func applyStatus(_ status: MessageStatus, isFromMe: Bool) {
        switch status {
        case .sending:
            statusIndicator.startAnimating()
            failedIcon.isHidden = true
        case .sent, .received:
            statusIndicator.stopAnimating()
            failedIcon.isHidden = true
        case .failed:
            statusIndicator.stopAnimating()
            failedIcon.isHidden = false
        }
    }
}
