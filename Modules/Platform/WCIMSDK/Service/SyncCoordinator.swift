import Foundation

/// Sync 主线编排:Service 拉一包 → 事务落库 → 推进 seqId → 广播变更
public final class SyncCoordinator {
    private let service: SyncServiceProtocol
    private let sessionDB: SessionDB
    private let seqIdManager: SeqIdManager
    private let changeStream: DBChangeStream

    private var inFlight = false
    private let lock = NSLock()

    public init(service: SyncServiceProtocol,
                sessionDB: SessionDB,
                seqIdManager: SeqIdManager,
                changeStream: DBChangeStream = .shared) {
        self.service = service
        self.sessionDB = sessionDB
        self.seqIdManager = seqIdManager
        self.changeStream = changeStream
    }

    /// 触发一次增量同步。并发触发自动合并 — 同时只跑一次,避免重复拉。
    public func triggerSync() async {
        lock.lock()
        if inFlight { lock.unlock(); return }
        inFlight = true
        lock.unlock()

        defer {
            lock.lock(); inFlight = false; lock.unlock()
        }

        do {
            let batch = try await service.fetchIncremental(after: seqIdManager.currentSeqId)
            try applyBatch(batch)
            seqIdManager.advance(to: batch.maxSeqId)
            print("[Sync] ✅ applied \(batch.sessions.count) sessions, advanced seqId → \(batch.maxSeqId)")
        } catch {
            print("[Sync] ❌ failed: \(error)")
        }
    }

    private func applyBatch(_ batch: SyncBatch) throws {
        guard !batch.sessions.isEmpty else { return }

        // 同 sessionId 聚合 — 只 upsert 一次
        var grouped: [String: SessionModel] = [:]
        for s in batch.sessions { grouped[s.sessionId] = s }
        let toUpsert = Array(grouped.values)
        let sessionIds = Array(grouped.keys)

        // 区分 insert vs update
        let existing = Set(sessionDB.fetch(sessionIds: sessionIds).map { $0.sessionId })
        let insertedIds = sessionIds.filter { !existing.contains($0) }
        let updatedIds = sessionIds.filter { existing.contains($0) }

        try sessionDB.runTransaction { [self] in
            try self.sessionDB.upsert(toUpsert)
        }

        // 事务成功才广播 — 失败抛错则上层 catch 住,不会到这里
        if !insertedIds.isEmpty { changeStream.publish(session: .insert(insertedIds)) }
        if !updatedIds.isEmpty  { changeStream.publish(session: .update(updatedIds)) }
    }
}
