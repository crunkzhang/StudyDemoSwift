import UIKit
import SnapKit
import ExtensionKit

final class ContactDetailActionBar: UIView {
    let messageButton = UIButton(type: .system)
    let callButton = UIButton(type: .system)

    var onMessage: (() -> Void)?
    var onCall: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white

        let top = UIView()
        top.backgroundColor = UIColor(hex: "#E5E5E5")
        addSubview(top)
        top.snp.makeConstraints { $0.leading.trailing.top.equalToSuperview(); $0.height.equalTo(1.0 / UIScreen.main.scale) }

        [messageButton, callButton].forEach { addSubview($0) }
        configure(messageButton, title: "发消息", bg: UIColor(hex: "#07C160"), fg: .white, border: false)
        configure(callButton, title: "音视频通话", bg: .white, fg: UIColor(hex: "#07C160"), border: true)

        messageButton.addTarget(self, action: #selector(tapMsg), for: .touchUpInside)
        callButton.addTarget(self, action: #selector(tapCall), for: .touchUpInside)

        messageButton.snp.makeConstraints {
            $0.leading.equalToSuperview().offset(16)
            $0.top.equalToSuperview().offset(10)
            $0.bottom.equalTo(safeAreaLayoutGuide.snp.bottom).offset(-10)
            $0.height.equalTo(48)
        }
        callButton.snp.makeConstraints {
            $0.leading.equalTo(messageButton.snp.trailing).offset(12)
            $0.trailing.equalToSuperview().offset(-16)
            $0.top.bottom.equalTo(messageButton)
            $0.width.equalTo(messageButton)
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    private func configure(_ btn: UIButton, title: String, bg: UIColor, fg: UIColor, border: Bool) {
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
        btn.addTarget(self, action: #selector(pressDown(_:)), for: [.touchDown, .touchDragEnter])
        btn.addTarget(self, action: #selector(pressUp(_:)), for: [.touchUpInside, .touchUpOutside, .touchDragExit, .touchCancel])
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
