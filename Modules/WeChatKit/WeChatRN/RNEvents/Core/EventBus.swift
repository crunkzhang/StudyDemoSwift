import Foundation

/// 统一事件总线 —— 所有原生 → JS 事件都走这里发。
/// 业务侧不直接操作 RCTEventEmitter，解除对 EventBridge 的耦合。
public enum EventBus {
    nonisolated(unsafe) static weak var emitter: EventBridge?

    /// 发送事件到 JS 侧。topic 必须在 EventRegistry 中预先声明。
    public static func emit(_ topic: String, payload: [String: Any] = [:]) {
        DispatchQueue.main.async {
            emitter?.dispatch(topic: topic, payload: payload)
        }
    }
}
