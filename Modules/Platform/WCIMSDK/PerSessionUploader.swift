import Foundation

/// 单会话上行串行器 — 用 actor 天然串行 + Task 链式等待替代 DispatchQueue。
/// 之前 SendQueueManager 用 DispatchQueue.async 套 Task { } 实际是并发跑(Task 立刻让 dispatch 块返回),
/// 串行语义假的。actor + previous?.value 真正保证同会话顺序上行。
public actor PerSessionUploader {
    private let sessionId: String
    private let push: PushServiceProtocol
    private let messageDB: MessageDB
    private let changeStream: DBChangeStream

    /// 链上一个 Task,新任务 await 它后再跑 — 保证严格串行。
    private var lastTask: Task<Void, Never>?

    public init(sessionId: String,
                push: PushServiceProtocol,
                messageDB: MessageDB,
                changeStream: DBChangeStream = .shared) {
        self.sessionId = sessionId
        self.push = push
        self.messageDB = messageDB
        self.changeStream = changeStream
    }

    /// 入队上行 — fire-and-forget,调用方不必 await。
    public func enqueue(localMsgId: String, traceId: String, contentJSON: String) {
        let previous = lastTask
        lastTask = Task { [self] in
            await previous?.value   // 等前一个 task 完成
            await uploadWithRetry(localMsgId: localMsgId, traceId: traceId, contentJSON: contentJSON)
        }
    }

    // MARK: - Private

    private func uploadWithRetry(localMsgId: String, traceId: String, contentJSON: String) async {
        let delays: [UInt64] = [0, 1_000_000_000, 2_000_000_000, 4_000_000_000]  // 4 次 0/1s/2s/4s
        for (i, d) in delays.enumerated() {
            if d > 0 { try? await Task.sleep(nanoseconds: d) }
            do {
                let result = try await push.upload(
                    localMsgId: localMsgId,
                    traceId: traceId,
                    sessionId: sessionId,
                    contentJSON: contentJSON
                )
                applyACK(localMsgId: localMsgId, result: result)
                return
            } catch {
                print("[Send] retry \(i + 1)/\(delays.count) failed: \(error)")
            }
        }
        markFailed(localMsgId: localMsgId)
    }

    private func applyACK(localMsgId: String, result: PushUploadResult) {
        var commitedMessage: MessageModel?
        do {
            try messageDB.runTransaction { [self] in
                try self.messageDB.update(localMsgId: localMsgId, sessionId: self.sessionId) { m in
                    m.msgId = result.msgId
                    m.seqId = result.seqId
                    m.status = MessageStatus.sent.rawValue
                    m.timestamp = result.timestamp
                }
            }
            commitedMessage = messageDB.fetch(localMsgIds: [localMsgId], sessionId: sessionId).first
        } catch {
            print("[Send] applyACK 事务失败: \(error)")
            return
        }
        // 事务成功才广播
        if let m = commitedMessage {
            changeStream.publish(message: .update(sessionId: sessionId, messages: [m]), sessionId: sessionId)
        }
    }

    private func markFailed(localMsgId: String) {
        var commitedMessage: MessageModel?
        do {
            try messageDB.runTransaction { [self] in
                try self.messageDB.update(localMsgId: localMsgId, sessionId: self.sessionId) { m in
                    m.status = MessageStatus.failed.rawValue
                }
            }
            commitedMessage = messageDB.fetch(localMsgIds: [localMsgId], sessionId: sessionId).first
        } catch {
            return
        }
        if let m = commitedMessage {
            changeStream.publish(message: .update(sessionId: sessionId, messages: [m]), sessionId: sessionId)
        }
    }
}

/// 进程级 registry — 多 ChatDetailLogic 实例(同会话先 pop 再 push)共享同一 uploader,
/// 避免并行 race。NSLock 保护字典即可,uploader 自身是 actor 内部串行。
public final class PerSessionUploaderRegistry {
    public static let shared = PerSessionUploaderRegistry()
    private var uploaders: [String: PerSessionUploader] = [:]
    private let lock = NSLock()

    public init() {}

    public func uploader(for sessionId: String,
                         push: PushServiceProtocol,
                         messageDB: MessageDB) -> PerSessionUploader {
        lock.lock(); defer { lock.unlock() }
        if let u = uploaders[sessionId] { return u }
        let u = PerSessionUploader(sessionId: sessionId, push: push, messageDB: messageDB)
        uploaders[sessionId] = u
        return u
    }
}
