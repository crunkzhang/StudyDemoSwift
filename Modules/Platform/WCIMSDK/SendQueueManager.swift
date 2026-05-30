import Foundation

/// 跨 MessageStore 共享的发送队列管理器。
/// 单 sessionId 串行(保顺序)、不同 sessionId 各走各的(并发)。
public final class SendQueueManager {
    public static let shared = SendQueueManager()

    private var queues: [String: DispatchQueue] = [:]
    private let lock = NSLock()

    public init() {}

    public func queue(for sessionId: String) -> DispatchQueue {
        lock.lock(); defer { lock.unlock() }
        if let q = queues[sessionId] { return q }
        let q = DispatchQueue(label: "im.send.\(sessionId)")  // 默认 serial
        queues[sessionId] = q
        return q
    }
}
