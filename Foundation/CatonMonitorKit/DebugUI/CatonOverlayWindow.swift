import UIKit

public final class CatonOverlayWindow: UIWindow {

    private let fpsLabel = UILabel()
    private let catonLabel = UILabel()
    private let containerView = UIView()
    private var catonCount: Int = 0
    private var recentEvents: [CatonEvent] = []
    private var detailExpanded = false
    private let detailStackView = UIStackView()

    public override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)
        setup()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setup() {
        windowLevel = .statusBar + 1
        isHidden = false
        isUserInteractionEnabled = true
        backgroundColor = .clear

        let width: CGFloat = 80
        let height: CGFloat = 44
        let topPadding = windowScene?.statusBarManager?.statusBarFrame.height ?? 44
        frame = CGRect(x: UIScreen.main.bounds.width - width - 8,
                       y: topPadding + 4,
                       width: width, height: height)

        containerView.frame = bounds
        containerView.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        containerView.layer.cornerRadius = 6
        containerView.clipsToBounds = true
        addSubview(containerView)

        fpsLabel.frame = CGRect(x: 4, y: 2, width: width - 8, height: 18)
        fpsLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        fpsLabel.textColor = .green
        fpsLabel.text = "FPS: --"
        containerView.addSubview(fpsLabel)

        catonLabel.frame = CGRect(x: 4, y: 22, width: width - 8, height: 18)
        catonLabel.font = UIFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        catonLabel.textColor = .white
        catonLabel.text = "Caton: 0"
        containerView.addSubview(catonLabel)

        detailStackView.axis = .vertical
        detailStackView.spacing = 2
        detailStackView.isHidden = true
        containerView.addSubview(detailStackView)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        containerView.addGestureRecognizer(pan)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        containerView.addGestureRecognizer(tap)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
        containerView.addGestureRecognizer(longPress)
    }

    // MARK: - Public Updates

    public func updateFPS(_ fps: Int) {
        fpsLabel.text = "FPS: \(fps)"
        if fps >= 45 {
            fpsLabel.textColor = .green
        } else if fps >= 30 {
            fpsLabel.textColor = .yellow
        } else {
            fpsLabel.textColor = .red
        }
    }

    public func recordCaton(_ event: CatonEvent) {
        catonCount += 1
        catonLabel.text = "Caton: \(catonCount)"

        recentEvents.append(event)
        if recentEvents.count > 5 {
            recentEvents.removeFirst()
        }

        flashRed()
        updateDetailIfExpanded()
    }

    // MARK: - Flash

    private func flashRed() {
        let original = containerView.backgroundColor
        UIView.animate(withDuration: 0.15, animations: {
            self.containerView.backgroundColor = UIColor.red.withAlphaComponent(0.8)
        }) { _ in
            UIView.animate(withDuration: 0.15) {
                self.containerView.backgroundColor = original
            }
        }
    }

    // MARK: - Gestures

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: superview)
        center = CGPoint(x: center.x + translation.x, y: center.y + translation.y)
        gesture.setTranslation(.zero, in: superview)
    }

    @objc private func handleTap() {
        detailExpanded.toggle()
        if detailExpanded {
            expandDetail()
        } else {
            collapseDetail()
        }
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        if let lastEvent = recentEvents.last {
            let stackString = lastEvent.stackTrace.joined(separator: "\n")
            UIPasteboard.general.string = "[\(lastEvent.type.rawValue)] \(lastEvent.page ?? "?")\n\(stackString)"

            let original = containerView.backgroundColor
            containerView.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.containerView.backgroundColor = original
            }
        }
    }

    // MARK: - Detail Panel

    private func expandDetail() {
        detailStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for event in recentEvents.suffix(5) {
            let label = UILabel()
            label.font = UIFont.monospacedSystemFont(ofSize: 9, weight: .regular)
            label.textColor = .white
            let page = event.page ?? "Unknown"
            label.text = "  \(page) \(Int(event.duration))ms"
            detailStackView.addArrangedSubview(label)
        }

        let detailHeight = CGFloat(min(recentEvents.count, 5)) * 14
        let newHeight: CGFloat = 44 + detailHeight + 4
        detailStackView.frame = CGRect(x: 4, y: 44, width: bounds.width - 8, height: detailHeight)
        detailStackView.isHidden = false

        frame.size.height = newHeight
        containerView.frame = bounds
    }

    private func collapseDetail() {
        detailStackView.isHidden = true
        frame.size.height = 44
        containerView.frame = bounds
    }

    private func updateDetailIfExpanded() {
        guard detailExpanded else { return }
        expandDetail()
    }

    // MARK: - 不拦截非浮窗区域的触摸

    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        return view == self ? nil : view
    }
}
