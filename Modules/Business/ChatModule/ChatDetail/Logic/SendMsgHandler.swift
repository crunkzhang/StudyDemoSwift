import Foundation
import WCIMSDK

final class SendMsgHandler {
    private let sessionId: String
    private let myUserId: String
    private let messageDB: MessageDB
    private let sessionDB: SessionDB
    private let pushService: PushServiceProtocol
    private let queue: DispatchQueue

    init(sessionId: String, myUserId: String) {
        guard let mdb = WCIMSDK.messageDB,
              let sdb = WCIMSDK.sessionDB,
              let push = WCIMSDK.pushService else {
            fatalError("WCIMSDK not setup before SendMsgHandler")
        }
        self.sessionId = sessionId
        self.myUserId = myUserId
        self.messageDB = mdb
        self.sessionDB = sdb
        self.pushService = push
        self.queue = SendQueueManager.shared.queue(for: sessionId)
    }

    /// 入口:发送文本
    func send(text: String) async {
        let localMsgId = UUID().uuidString
        let traceId = UUID().uuidString
        let now = Int64(Date().timeIntervalSince1970)
        let contentJSON = encodeText(text)

        // 1. 写 DB(status=sending)+ Session lastMsg 同步
        let pending = MessageModel()
        pending.localMsgId = localMsgId
        pending.sessionId = sessionId
        pending.senderId = myUserId
        pending.contentType = MessageContentType.text.rawValue
        pending.contentJSON = contentJSON
        pending.timestamp = now
        pending.status = MessageStatus.sending.rawValue
        pending.traceId = traceId

        do {
            try messageDB.runTransaction { [self] in
                try self.messageDB.upsert([pending], sessionId: self.sessionId)
                if let s = self.sessionDB.fetch(sessionIds: [self.sessionId]).first {
                    s.lastMsgPreview = text
                    s.lastTimestamp = now
                    try self.sessionDB.upsert([s])
                    DBChangeStream.shared.publish(session: .update([self.sessionId]))
                }
            }
            DBChangeStream.shared.publish(
                message: .insert(sessionId: sessionId, messages: [pending]),
                sessionId: sessionId
            )
        } catch {
            print("[Send] ❌ DB write failed: \(error)")
            return
        }

        // 2. SendQueueManager 串行排队上行(可能重试)
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            queue.async { [weak self] in
                Task {
                    await self?.uploadWithRetry(
                        localMsgId: localMsgId,
                        traceId: traceId,
                        contentJSON: contentJSON
                    )
                    cont.resume()
                }
            }
        }
    }

    /// 重发:localMsgId 不变,traceId 新生成
    func retry(localMsgId: String) async {
        guard let m = messageDB.fetch(localMsgIds: [localMsgId], sessionId: sessionId).first else { return }
        let newTraceId = UUID().uuidString
        m.status = MessageStatus.sending.rawValue
        m.traceId = newTraceId

        do {
            try messageDB.runTransaction { [self] in
                try self.messageDB.upsert([m], sessionId: self.sessionId)
            }
            DBChangeStream.shared.publish(
                message: .update(sessionId: sessionId, messages: [m]),
                sessionId: sessionId
            )
        } catch {}

        let contentJSON = m.contentJSON
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            queue.async { [weak self] in
                Task {
                    await self?.uploadWithRetry(
                        localMsgId: localMsgId,
                        traceId: newTraceId,
                        contentJSON: contentJSON
                    )
                    cont.resume()
                }
            }
        }
    }

    // MARK: - 私有

    private func uploadWithRetry(localMsgId: String, traceId: String, contentJSON: String) async {
        let delays: [UInt64] = [0, 1_000_000_000, 2_000_000_000, 4_000_000_000]  // 4 次 0/1s/2s/4s
        for (i, d) in delays.enumerated() {
            if d > 0 { try? await Task.sleep(nanoseconds: d) }
            do {
                let result = try await pushService.upload(
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
        do {
            try messageDB.runTransaction { [self] in
                try self.messageDB.update(localMsgId: localMsgId, sessionId: self.sessionId) { m in
                    m.msgId = result.msgId
                    m.seqId = result.seqId
                    m.status = MessageStatus.sent.rawValue
                    m.timestamp = result.timestamp
                }
            }
            if let m = messageDB.fetch(localMsgIds: [localMsgId], sessionId: sessionId).first {
                DBChangeStream.shared.publish(
                    message: .update(sessionId: sessionId, messages: [m]),
                    sessionId: sessionId
                )
            }
        } catch {}
    }

    private func markFailed(localMsgId: String) {
        do {
            try messageDB.runTransaction { [self] in
                try self.messageDB.update(localMsgId: localMsgId, sessionId: self.sessionId) { m in
                    m.status = MessageStatus.failed.rawValue
                }
            }
            if let m = messageDB.fetch(localMsgIds: [localMsgId], sessionId: sessionId).first {
                DBChangeStream.shared.publish(
                    message: .update(sessionId: sessionId, messages: [m]),
                    sessionId: sessionId
                )
            }
        } catch {}
    }

    private func encodeText(_ text: String) -> String {
        // 简单 JSON 编码,避免引号转义错乱
        let payload = ["text": text]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
}
