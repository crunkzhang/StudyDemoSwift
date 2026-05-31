import Foundation

public enum BridgeResult {
    case success([String: Any])
    case failure(code: String, message: String)
}

public protocol GameBridgeHandler {
    /// 命名空间,如 "ai";GameBridge 按 method 的前缀("ai.ask" → "ai")派发
    var namespace: String { get }
    func handle(method: String, params: [String: Any]) async -> BridgeResult
}

/// 支持流式的 handler:中途通过 emit(delta) 推送增量,最后返回 BridgeResult。
public protocol GameBridgeStreamHandler {
    func handleStream(method: String, params: [String: Any],
                      emit: @escaping (String) -> Void) async -> BridgeResult
}
