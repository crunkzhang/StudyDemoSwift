import UIKit

private enum ToastBridgeSignals {
    static let didShow = "toastBridge:didShow"
}

final class ToastBridgeHandler {
    static let shared = ToastBridgeHandler()

    private weak var currentToastView: UIView?

    private init() {}

    func show(message: String, duration: TimeInterval) {
        guard let containerView = RNBridgeContext.shared.currentViewController?.view else {
            return
        }

        currentToastView?.removeFromSuperview()

        let label = PaddingLabel()
        label.text = message
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.backgroundColor = UIColor(white: 0.1, alpha: 0.9)
        label.layer.cornerRadius = 18
        label.layer.masksToBounds = true
        label.alpha = 0
        label.insets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        label.numberOfLines = 0
        label.textAlignment = .center

        containerView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            label.bottomAnchor.constraint(
                equalTo: containerView.safeAreaLayoutGuide.bottomAnchor,
                constant: -32
            ),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: containerView.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: containerView.trailingAnchor, constant: -24)
        ])

        currentToastView = label

        UIView.animate(withDuration: 0.2) {
            label.alpha = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self, weak label] in
            guard let label else { return }
            UIView.animate(withDuration: 0.2, animations: {
                label.alpha = 0
            }, completion: { _ in
                label.removeFromSuperview()
                if self?.currentToastView === label {
                    self?.currentToastView = nil
                }
            })
        }

        RNBridgeContext.shared.emit(signal: ToastBridgeSignals.didShow, payload: ["message": message])
    }
}

private final class PaddingLabel: UILabel {
    var insets = UIEdgeInsets.zero

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + insets.left + insets.right,
            height: size.height + insets.top + insets.bottom
        )
    }
}
