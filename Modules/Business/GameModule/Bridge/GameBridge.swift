import Foundation
import WebKit

public final class GameBridge: NSObject, WKScriptMessageHandler {
    public static let messageHandlerName = "WCGameBridge"

    private weak var webView: WKWebView?
    private var handlers: [String: GameBridgeHandler] = [:]   // namespace -> handler

    public override init() { super.init() }
    public init(webView: WKWebView) { self.webView = webView; super.init() }

    public func attach(to webView: WKWebView) { self.webView = webView }

    public func register(handler: GameBridgeHandler) {
        handlers[handler.namespace] = handler
    }

    /// 可测的纯派发:按 method 前缀找 handler
    public func resolve(method: String, params: [String: Any]) async -> BridgeResult {
        let ns = method.split(separator: ".").first.map(String.init) ?? ""
        guard let handler = handlers[ns] else {
            return .failure(code: "NO_HANDLER", message: "no handler for \(ns)")
        }
        return await handler.handle(method: method, params: params)
    }

    // MARK: - WKScriptMessageHandler

    public func userContentController(_ uc: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Self.messageHandlerName,
              let body = message.body as? [String: Any],
              let callId = body["callId"] as? String,
              let method = body["method"] as? String else { return }
        let params = body["params"] as? [String: Any] ?? [:]
        let stream = body["stream"] as? Bool ?? false

        let ns = method.split(separator: ".").first.map(String.init) ?? ""

        if stream, let handler = handlers[ns] as? GameBridgeStreamHandler {
            Task {
                let result = await handler.handleStream(method: method, params: params) { [weak self] delta in
                    Task { @MainActor in self?.emit(callId: callId, delta: delta) }
                }
                await MainActor.run { self.callback(callId: callId, result: result) }
            }
            return
        }

        Task {
            let result = await resolve(method: method, params: params)
            await MainActor.run { self.callback(callId: callId, result: result) }
        }
    }

    @MainActor
    private func emit(callId: String, delta: String) {
        guard let data = try? JSONSerialization.data(withJSONObject: ["delta": delta]),
              let json = String(data: data, encoding: .utf8) else { return }
        webView?.evaluateJavaScript("window.WCGameBridge && window.WCGameBridge._emit('\(callId)', \(json));", completionHandler: nil)
    }

    private func callback(callId: String, result: BridgeResult) {
        let payload: [String: Any]
        switch result {
        case .success(let data):
            payload = ["ok": true, "data": data]
        case .failure(let code, let message):
            payload = ["ok": false, "error": ["code": code, "message": message]]
        }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: jsonData, encoding: .utf8) else { return }
        let js = "window.WCGameBridge && window.WCGameBridge._resolve('\(callId)', \(json));"
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }
}
