import UIKit
import SnapKit
import ExtensionKit

final class ContactDetailActionBar: UIView {
    var onMessage: (() -> Void)?
    var onCall: (() -> Void)?

    private lazy var topSeparator: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(hex: "#E5E5E5")
        return v
    }()

    private lazy var messageButton: UIButton = makeButton(
        title: "发消息", bg: UIColor(hex: "#07C160"), fg: .white, border: false,
        action: #selector(tapMsg))

    private lazy var callButton: UIButton = makeButton(
        title: "音视频通话", bg: .white, fg: UIColor(hex: "#07C160"), border: true,
        action: #selector(tapCall))

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        setupSubviews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupSubviews() {
        [topSeparator, messageButton, callButton].forEach { addSubview($0) }

        topSeparator.snp.makeConstraints {
            $0.leading.trailing.top.equalToSuperview()
            $0.height.equalTo(1.0 / UIScreen.main.scale)
        }
        messageButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(16)
            $0.top.equalToSuperview().offset(10)
            $0.bottom.equalToSuperview().offset(-10)
            $0.height.equalTo(48)
        }
        callButton.snp.makeConstraints {
            $0.leading.equalTo(messageButton.snp.trailing).offset(12)
            $0.trailing.equalToSuperview().offset(-16)
            $0.top.bottom.equalTo(messageButton)
            $0.width.equalTo(messageButton)
        }
    }

    private func makeButton(title: String, bg: UIColor, fg: UIColor, border: Bool, action: Selector) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        btn.setTitleColor(fg, for: .normal)
        btn.backgroundColor = bg
        btn.layer.cornerRadius = 8
        btn.layer.masksToBounds = true
        if border {
            btn.layer.borderWidth = 1
            btn.layer.borderColor = UIColor(hex: "#07C160").cgColor
        }
        btn.addTarget(self, action: action, for: .touchUpInside)
        btn.addTarget(self, action: #selector(pressDown(_:)), for: [.touchDown, .touchDragEnter])
        btn.addTarget(self, action: #selector(pressUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchDragExit, .touchCancel])
        return btn
    }

    @objc private func pressDown(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) { sender.transform = CGAffineTransform(scaleX: 0.97, y: 0.97) }
    }
    @objc private func pressUp(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) { sender.transform = .identity }
    }

    @objc private func tapMsg() { onMessage?() }
    @objc private func tapCall() { onCall?() }
}
