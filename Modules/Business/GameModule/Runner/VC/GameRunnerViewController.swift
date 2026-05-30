import UIKit
import WebKit
import SnapKit
import WeChatUI
import WeChatRouter
import NavigateKit
import ExtensionKit

public final class GameRunnerViewController: BaseViewController, PageRoutable {

    public static var routePattern: String { "game/run" }
    public static func createPage(with params: [String: String]) -> UIViewController? {
        guard let id = params["id"] else { return nil }
        return GameRunnerViewController(gameId: id)
    }

    private let gameId: String
    private let webView: WKWebView

    private let loadingView = UIActivityIndicatorView(style: .large)
    private let loadingLabel: UILabel = {
        let l = UILabel()
        l.textColor = .white
        l.font = .systemFont(ofSize: 13)
        l.textAlignment = .center
        l.isHidden = true
        return l
    }()
    private let errorContainer = UIView()
    private let errorLabel: UILabel = {
        let l = UILabel()
        l.textColor = .white
        l.font = .systemFont(ofSize: 14)
        l.textAlignment = .center
        l.numberOfLines = 0
        return l
    }()
    private let retryButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("重试", for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        b.backgroundColor = UIColor(red: 0.027, green: 0.756, blue: 0.376, alpha: 1)
        b.layer.cornerRadius = 8
        b.contentEdgeInsets = UIEdgeInsets(top: 8, left: 24, bottom: 8, right: 24)
        return b
    }()

    private var state: GameLoadState = .idle {
        didSet { applyState() }
    }

    private var originalGestureDelegate: UIGestureRecognizerDelegate?
    /// 独立的 delegate 对象,而不是让 self 直接当 delegate。
    /// 原因:UINavigationController 在 didShow 时会重置 interactivePopGesture 的
    /// isEnabled 和 delegate,若 self 当 delegate,super.viewWillAppear 之后
    /// UINav 可能立刻覆盖。独立对象 + viewDidAppear 设置 = 最稳。
    private let noSwipeBackDelegate = NoSwipeBackGestureDelegate()

    public init(gameId: String) {
        self.gameId = gameId
        self.webView = Self.makeWebView()
        super.init(nibName: nil, bundle: nil)
        // 标题先放 id 兜底,viewDidLoad 里从 manifest 替换成真实 title
        title = gameId
    }
    required init?(coder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        // 从 manifest 取真实标题 + 背景色
        let game = GameBundleManager.shared.currentManifest?.games.first { $0.id == gameId }
        if let realTitle = game?.title, !realTitle.isEmpty { title = realTitle }
        let bgColor = game?.backgroundColor.flatMap { UIColor(hex: $0) } ?? .white
        view.backgroundColor = bgColor
        webView.backgroundColor = bgColor
        webView.scrollView.backgroundColor = bgColor

        view.addSubview(webView)
        view.addSubview(loadingView)
        view.addSubview(loadingLabel)
        errorContainer.isHidden = true
        errorContainer.addSubview(errorLabel)
        errorContainer.addSubview(retryButton)
        view.addSubview(errorContainer)

        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.bottom.equalToSuperview()
        }
        loadingView.snp.makeConstraints { $0.center.equalToSuperview() }
        loadingLabel.snp.makeConstraints { make in
            make.top.equalTo(loadingView.snp.bottom).offset(12)
            make.centerX.equalToSuperview()
        }
        errorContainer.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(20)
            make.trailing.lessThanOrEqualToSuperview().offset(-20)
        }
        errorLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        retryButton.snp.makeConstraints { make in
            make.top.equalTo(errorLabel.snp.bottom).offset(16)
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)

        Task { await loadGame() }
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 必须在 viewDidAppear 设置:UINavigationController 在 _didShowViewController
        // 阶段(即 viewDidAppear 之前一刻)会自动按栈深恢复 isEnabled,
        // 之前在 viewWillAppear 设的会被吞掉。
        disableSystemSwipeBack()

        #if DEBUG
        // 一次性诊断:列出 nav.view 上所有 gesture,确认没有漏网之鱼
        navigationController?.view.gestureRecognizers?.forEach {
            print("[Game] nav-gesture: \(type(of: $0)) enabled=\($0.isEnabled) delegate=\(String(describing: $0.delegate))")
        }
        #endif
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreSystemSwipeBack()
    }

    private func disableSystemSwipeBack() {
        guard let gesture = navigationController?.interactivePopGestureRecognizer else { return }
        if originalGestureDelegate == nil { originalGestureDelegate = gesture.delegate }
        gesture.delegate = noSwipeBackDelegate
        gesture.isEnabled = false
    }

    private func restoreSystemSwipeBack() {
        guard let gesture = navigationController?.interactivePopGestureRecognizer else { return }
        gesture.delegate = originalGestureDelegate
        gesture.isEnabled = true
        originalGestureDelegate = nil
    }

    @objc private func retryTapped() {
        Task { await loadGame() }
    }

    private func loadGame(useFallback: Bool = false) async {
        await MainActor.run { self.state = .downloading }

        let localURL: URL? = useFallback
            ? GameBundleManager.shared.fallbackBundleURL(for: gameId)
            : await GameBundleManager.shared.bundleURL(for: gameId)

        guard let url = localURL else {
            if !useFallback {
                await loadGame(useFallback: true)
            } else {
                await MainActor.run { self.state = .failed(reason: "游戏加载失败") }
            }
            return
        }
        await MainActor.run {
            self.state = .ready
            self.webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
    }

    private func applyState() {
        switch state {
        case .idle:
            loadingView.isHidden = true
            loadingLabel.isHidden = true
            errorContainer.isHidden = true
            webView.isHidden = true
        case .downloading:
            loadingView.startAnimating()
            loadingView.isHidden = false
            loadingLabel.text = "下载中..."
            loadingLabel.isHidden = false
            errorContainer.isHidden = true
            webView.isHidden = true
        case .ready:
            loadingView.stopAnimating()
            loadingView.isHidden = true
            loadingLabel.isHidden = true
            errorContainer.isHidden = true
            webView.isHidden = false
        case .failed(let reason):
            loadingView.stopAnimating()
            loadingView.isHidden = true
            loadingLabel.isHidden = true
            errorLabel.text = reason
            errorContainer.isHidden = false
            webView.isHidden = true
        }
    }

    private static func makeWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let wv = WKWebView(frame: .zero, configuration: config)
        // 真正的底色在 viewDidLoad 里按 manifest 设;这里只是个初始占位
        wv.backgroundColor = .white
        wv.isOpaque = false
        wv.scrollView.bounces = false
        wv.scrollView.isScrollEnabled = false
        return wv
    }
}

// MARK: - 独立的 UIGestureRecognizerDelegate(只为屏蔽 interactivePopGesture)

private final class NoSwipeBackGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldReceive touch: UITouch) -> Bool {
        return false
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        return false
    }
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool {
        return false
    }
}
