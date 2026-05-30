import Foundation
import WCIMSDK

/// 发送协调器(per session) — 负责:
/// 1. 写本地 sending 消息到 DB(同步)
/// 2. 同步更新 SessionDB.lastMsg(独立事务,避免假"跨库事务")
/// 3. 广播 DBChangeStream(事务成功后才发,事务回滚不广播假状态)
/// 4. fire-and-forget 把上行交给 PerSessionUploader(actor 串行 + 链式 Task)
///
/// 与之前版本相比:
/// - send/retry 改为同步接口,UI 立刻拿回控制权(不再 await ACK)
/// - 真正的串行由 PerSessionUploader actor 保证(替代假串行的 DispatchQueue.async)
/// - publish 移出 DB transaction,事务回滚不再发出虚假广播
/// - 依赖注入支持 mock 测试
final class SendMsgHandler {
    private let sessionId: String
    private let myUserId: String
    private let messageDB: MessageDB
    private let sessionDB: SessionDB
    private let changeStream: DBChangeStream
    private let uploader: PerSessionUploader

    init(sessionId: String,
         myUserId: String,
         messageDB: MessageDB,
         sessionDB: SessionDB,
         pushService: PushServiceProtocol,
         changeStream: DBChangeStream = .shared) {
        self.sessionId = sessionId
        self.myUserId = myUserId
        self.messageDB = messageDB
        self.sessionDB = sessionDB
        self.changeStream = changeStream
        self.uploader = PerSessionUploaderRegistry.shared.uploader(
            for: sessionId, push: pushService, messageDB: messageDB
        )
    }

    /// 便捷构造 — 默认从 WCIMSDK 全局实例取依赖
    convenience init(sessionId: String, myUserId: String) {
        guard let mdb = WCIMSDK.messageDB,
              let sdb = WCIMSDK.sessionDB,
              let push = WCIMSDK.pushService else {
            fatalError("SendMsgHandler 初始化时 WCIMSDK 未 setup")
        }
        self.init(sessionId: sessionId, myUserId: myUserId,
                  messageDB: mdb, sessionDB: sdb, pushService: push)
    }

    // MARK: - 公开入口(同步)

    /// 发送文本 — 同步返回,UI 立刻刷新 sending 气泡,上行在后台 actor 串行跑。
    func send(text: String) {
        let localMsgId = UUID().uuidString
        let traceId = UUID().uuidString
        let now = Int64(Date().timeIntervalSince1970)
        let contentJSON = MessageContent.text(text).jsonString

        // 1. 写 MessageDB(sending)
        let pending = buildPendingMessage(
            localMsgId: localMsgId, traceId: traceId,
            contentJSON: contentJSON, now: now
        )
        guard insertPending(pending) else { return }

        // 2. 独立事务同步 SessionDB.lastMsg(失败也不阻断上行)
        updateSessionPreview(text: text, timestamp: now)

        // 3. 广播 message.insert(在 DB 事务之外,事务回滚不会到这里)
        changeStream.publish(
            message: .insert(sessionId: sessionId, messages: [pending]),
            sessionId: sessionId
        )

        // 4. fire-and-forget 入队 uploader(actor 串行)
        Task {
            await uploader.enqueue(localMsgId: localMsgId, traceId: traceId, contentJSON: contentJSON)
        }
    }

    /// 重发失败消息 — localMsgId 不变,traceId 重生(用于链路监控区分尝试)。
    func retry(localMsgId: String) {
        guard let m = messageDB.fetch(localMsgIds: [localMsgId], sessionId: sessionId).first else { return }
        let newTraceId = UUID().uuidString
        m.status = MessageStatus.sending.rawValue
        m.traceId = newTraceId

        do {
            try messageDB.runTransaction { [self] in
                try self.messageDB.upsert([m], sessionId: self.sessionId)
            }
        } catch {
            print("[Send] retry DB write failed: \(error)")
            return
        }

        changeStream.publish(
            message: .update(sessionId: sessionId, messages: [m]),
            sessionId: sessionId
        )

        let contentJSON = m.contentJSON
        Task {
            await uploader.enqueue(localMsgId: localMsgId, traceId: newTraceId, contentJSON: contentJSON)
        }
    }

    // MARK: - 私有

    private func buildPendingMessage(localMsgId: String, traceId: String,
                                     contentJSON: String, now: Int64) -> MessageModel {
        let m = MessageModel()
        m.localMsgId = localMsgId
        m.sessionId = sessionId
        m.senderId = myUserId
        m.contentType = MessageContentType.text.rawValue
        m.contentJSON = contentJSON
        m.timestamp = now
        m.status = MessageStatus.sending.rawValue
        m.traceId = traceId
        return m
    }

    private func insertPending(_ m: MessageModel) -> Bool {
        do {
            try messageDB.runTransaction { [self] in
                try self.messageDB.upsert([m], sessionId: self.sessionId)
            }
            return true
        } catch {
            print("[Send] insertPending failed: \(error)")
            return false
        }
    }

    private func updateSessionPreview(text: String, timestamp: Int64) {
        guard let s = sessionDB.fetch(sessionIds: [sessionId]).first else { return }
        do {
            try sessionDB.runTransaction { [self] in
                s.lastMsgPreview = text
                s.lastTimestamp = timestamp
                try self.sessionDB.upsert([s])
            }
            // 事务成功后广播
            changeStream.publish(session: .update([sessionId]))
        } catch {
            print("[Send] updateSessionPreview failed: \(error)")
        }
    }
}
