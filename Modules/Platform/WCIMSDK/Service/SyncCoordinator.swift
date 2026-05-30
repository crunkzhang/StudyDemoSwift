import Foundation

/// Sync 主线编排:Service 拉一包 → 事务落库 → 推进 seqId → 广播变更
public final class SyncCoordinator {
    private let service: SyncServiceProtocol
    private let sessionDB: SessionDB
    private let messageDB: MessageDB
    private let seqIdManager: SeqIdManager
    private let changeStream: DBChangeStream

    private var inFlight = false
    private let lock = NSLock()

    public init(service: SyncServiceProtocol,
                sessionDB: SessionDB,
                messageDB: MessageDB,
                seqIdManager: SeqIdManager,
                changeStream: DBChangeStream = .shared) {
        self.service = service
        self.sessionDB = sessionDB
        self.messageDB = messageDB
        self.seqIdManager = seqIdManager
        self.changeStream = changeStream
    }

    /// 触发一次增量同步。并发触发自动合并 — 同时只跑一次,避免重复拉。
    /// - Parameter force: true 表示用户主动触发(Mock 服务才会吐新增量);
    ///   false 用于 viewDidAppear / 定时兜底等被动触发场景。
    public func triggerSync(force: Bool = false) async {
        lock.lock()
        if inFlight { lock.unlock(); return }
        inFlight = true
        lock.unlock()

        defer {
            lock.lock(); inFlight = false; lock.unlock()
        }

        do {
            let batch = try await service.fetchIncremental(
                after: seqIdManager.currentSeqId, force: force
            )
            try applyBatch(batch)
            seqIdManager.advance(to: batch.maxSeqId)
            print("[Sync] ✅ applied \(batch.sessions.count) sessions, advanced seqId → \(batch.maxSeqId) (force=\(force))")
        } catch {
            print("[Sync] ❌ failed: \(error)")
        }
    }

    private func applyBatch(_ batch: SyncBatch) throws {
        let messages = (batch.messages as? [MessageModel]) ?? []
        guard !batch.sessions.isEmpty || !messages.isEmpty else { return }

        var sessionGroup: [String: SessionModel] = [:]
        for s in batch.sessions { sessionGroup[s.sessionId] = s }

        var messageGroup: [String: [MessageModel]] = [:]
        for m in messages { messageGroup[m.sessionId, default: []].append(m) }

        let allSessionIds = Array(Set(sessionGroup.keys).union(messageGroup.keys))
        let existing = Set(sessionDB.fetch(sessionIds: allSessionIds).map(\.sessionId))
        let insertedIds = allSessionIds.filter { !existing.contains($0) }
        let updatedIds = allSessionIds.filter { existing.contains($0) }

        // SessionDB 事务为外层,MessageDB 事务嵌在内
        // (WCDB 跨 Database 实例事务相互独立,这里靠"事务全部成功才广播"保证一致性视角)
        try sessionDB.runTransaction { [self] in
            if !sessionGroup.isEmpty {
                try self.sessionDB.upsert(Array(sessionGroup.values))
            }
            try self.messageDB.runTransaction { [self] in
                for (sid, msgs) in messageGroup {
                    try self.messageDB.upsert(msgs, sessionId: sid)
                }
            }
        }

        if !insertedIds.isEmpty { changeStream.publish(session: .insert(insertedIds)) }
        if !updatedIds.isEmpty  { changeStream.publish(session: .update(updatedIds)) }
        for (sid, msgs) in messageGroup where !msgs.isEmpty {
            changeStream.publish(message: .insert(sessionId: sid, messages: msgs), sessionId: sid)
        }
    }
}
