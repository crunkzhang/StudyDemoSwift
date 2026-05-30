import UIKit
import SnapKit

public protocol ChatInputBarDelegate: AnyObject {
    func inputBarDidSend(_ text: String)
}

public final class ChatInputBar: UIView {
    public weak var delegate: ChatInputBarDelegate?

    private let textField: UITextField = {
        let tf = UITextField()
        tf.borderStyle = .roundedRect
        tf.font = .systemFont(ofSize: 16)
        tf.placeholder = "输入消息..."
        tf.returnKeyType = .send
        return tf
    }()

    private let sendButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("发送", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        b.backgroundColor = UIColor(red: 0.027, green: 0.756, blue: 0.376, alpha: 1)
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 6
        return b
    }()

    /// 输入栏背景色 — VC 设 view.backgroundColor 同色,避免键盘收起时 home indicator 那条露白。
    public static let barColor = UIColor(white: 0.97, alpha: 1)

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Self.barColor
        addSubview(textField)
        addSubview(sendButton)

        textField.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.top.equalToSuperview().offset(8)
            make.bottom.equalToSuperview().offset(-8)
            make.height.equalTo(36)
        }
        sendButton.snp.makeConstraints { make in
            make.leading.equalTo(textField.snp.trailing).offset(10)
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalTo(textField)
            make.width.equalTo(56)
            make.height.equalTo(36)
        }

        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        textField.delegate = self
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func sendTapped() {
        guard let text = textField.text, !text.isEmpty else { return }
        delegate?.inputBarDidSend(text)
        textField.text = ""
    }
}

extension ChatInputBar: UITextFieldDelegate {
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendTapped()
        return true
    }
}
