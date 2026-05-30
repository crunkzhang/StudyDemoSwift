import UIKit
import WebKit
import SnapKit
import WeChatUI
import WeChatRouter
import NavigateKit

public final class GameHallViewController: BaseViewController, PageRoutable {

    public static var routePattern: String { "game/hall" }
    public static func createPage(with params: [String: String]) -> UIViewController? {
        GameHallViewController()
    }

    private let webView: WKWebView = {
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.backgroundColor = UIColor(white: 0.93, alpha: 1)
        wv.isOpaque = false
        wv.scrollView.bounces = true
        return wv
    }()

    /// 上次注入的 payload(JSON 字符串本身就是 hash)。
    /// 用来判断是否需要 reload —— 数据没变就跳过 reload,WebView 内部状态(含滚动位置)天然保留。
    private var lastPayload: String?
    /// reload 前保存的滚动偏移,待 didFinish 后恢复。
    private var pendingScrollOffset: CGPoint?

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "游戏"
        view.backgroundColor = UIColor(white: 0.93, alpha: 1)

        webView.navigationDelegate = self
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(webView)
        webView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.leading.trailing.bottom.equalToSuperview()
        }

        loadHallIfChanged()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 拉一次 manifest,有变化再 reload;数据没变 → 跳过,滚动位置天然保留
        Task {
            await GameBundleManager.shared.refreshManifest()
            await MainActor.run { self.loadHallIfChanged() }
        }
    }

    /// 构造当前应注入的 payload JSON,作为唯一变更源 + hash
    private func buildPayload() -> String {
        let storage = GameBundleStorage()
        let manifest = GameBundleManager.shared.currentManifest
            ?? GameManifest(manifestVersion: 1, updatedAt: "", games: [])

        let visibleGames = manifest.games.filter { GameBundleManager.grayscaleHit(game: $0) }
        let gamesPayload: [[String: Any]] = visibleGames.map { g in
            [
                "id": g.id,
                "title": g.title,
                "subtitle": g.subtitle ?? "",
                "icon": g.icon,
                "version": g.version,
                "size": g.size,
                "downloaded": storage.hasBundle(id: g.id, version: g.version)
            ]
        }
        let wrapper: [String: Any] = ["games": gamesPayload]
        let data = (try? JSONSerialization.data(withJSONObject: wrapper)) ?? Data("{\"games\":[]}".utf8)
        return String(data: data, encoding: .utf8) ?? "{\"games\":[]}"
    }

    /// 只在 payload 真变了才重 load 整页;否则什么都不做,滚动位置由 WebView 自己保留。
    private func loadHallIfChanged() {
        let payload = buildPayload()
        if payload == lastPayload { return }

        // 即将 reload —— 先保存当前滚动,待 didFinish 后恢复
        pendingScrollOffset = webView.scrollView.contentOffset
        lastPayload = payload

        let script = "window.GAME_MANIFEST = \(payload);"
        webView.configuration.userContentController.removeAllUserScripts()
        webView.configuration.userContentController.addUserScript(WKUserScript(
            source: script,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))

        // 加载内置 hall.html(静态库 + s.resources -> 文件平铺在 main bundle)
        let url = Bundle.main.url(forResource: "hall", withExtension: "html")
            ?? Bundle(for: Self.self).url(forResource: "hall", withExtension: "html")
            ?? Bundle(for: Self.self).url(forResource: "hall", withExtension: "html", subdirectory: "Hall")
        guard let url else {
            print("[Game] ❌ hall.html 找不到 — 检查 podspec s.resources")
            return
        }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
}

// MARK: - WKNavigationDelegate

extension GameHallViewController: WKNavigationDelegate {
    public func webView(_ webView: WKWebView,
                        decidePolicyFor navigationAction: WKNavigationAction,
                        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow); return
        }
        // 拦截 wechat:// scheme,转给原生 Router
        if url.scheme == "wechat" {
            decisionHandler(.cancel)
            Router.shared.push(url.absoluteString)
            return
        }
        decisionHandler(.allow)
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // reload 完成后恢复上次的滚动位置
        guard let offset = pendingScrollOffset else { return }
        pendingScrollOffset = nil
        // 稍延后到下一帧,等 H5 列表渲染完 contentSize 再 setOffset
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
            self?.webView.scrollView.setContentOffset(offset, animated: false)
        }
    }
}
