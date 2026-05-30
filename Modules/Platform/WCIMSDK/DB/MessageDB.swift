import Foundation
import WCDBSwift

/// 每会话一张物理表 — 表名走 MessageTableNameRegistry SHA1 hash 截取。
public final class MessageDB {
    private let db: Database
    private let registry: MessageTableNameRegistry
    private var createdTables: Set<String> = []
    private let lock = NSLock()

    public init(userId: String, registry: MessageTableNameRegistry) {
        let path = DBPaths.messageDBPath(userId: userId)
        self.db = Database(at: path)
        self.registry = registry
    }

    // MARK: - 写

    public func upsert(_ messages: [MessageModel], sessionId: String) throws {
        let table = registry.tableName(for: sessionId)
        try ensureTable(table)
        try db.insertOrReplace(messages, intoTable: table)
    }

    /// 按 localMsgId 更新单条(发送 ACK 回填用)
    public func update(localMsgId: String, sessionId: String, mutate: (MessageModel) -> Void) throws {
        let table = registry.tableName(for: sessionId)
        try ensureTable(table)
        guard let m: MessageModel = try db.getObject(
            fromTable: table,
            where: MessageModel.Properties.localMsgId == localMsgId
        ) else { return }
        mutate(m)
        try db.insertOrReplace([m], intoTable: table)
    }

    // MARK: - 读

    /// 按 seqId 倒序分页(最新的在前;UI 显示时业务侧自行 reversed 成时间正序)
    public func fetchPage(sessionId: String, beforeSeqId: Int64? = nil, limit: Int = 20) -> [MessageModel] {
        let table = registry.tableName(for: sessionId)
        try? ensureTable(table)
        // 按 timestamp 排序而不是 seqId — pending 消息 seqId=0(server 未分配),
        // 按 timestamp 排序天然落底(now 最大)。ACK 回填后 timestamp 更新但仍
        // 在最新区间,顺序稳定不闪。seqId 仍用于增量同步锚点,只是不参与 UI 排序。
        do {
            if let before = beforeSeqId {
                return try db.getObjects(
                    fromTable: table,
                    where: MessageModel.Properties.seqId < before,
                    orderBy: [MessageModel.Properties.timestamp.order(.descending)],
                    limit: limit
                )
            } else {
                return try db.getObjects(
                    fromTable: table,
                    orderBy: [MessageModel.Properties.timestamp.order(.descending)],
                    limit: limit
                )
            }
        } catch {
            return []
        }
    }

    public func fetch(localMsgIds: [String], sessionId: String) -> [MessageModel] {
        guard !localMsgIds.isEmpty else { return [] }
        let table = registry.tableName(for: sessionId)
        try? ensureTable(table)
        return (try? db.getObjects(
            fromTable: table,
            where: MessageModel.Properties.localMsgId.in(localMsgIds)
        )) ?? []
    }

    // MARK: - 事务

    public func runTransaction(_ block: @escaping () throws -> Void) throws {
        try db.run(transaction: { _ in try block() })
    }

    /// 清空所有消息表(DEBUG 用)。DROP 已知表 + 清空 created 缓存。
    public func wipeAll() throws {
        lock.lock()
        let tables = createdTables
        createdTables.removeAll()
        lock.unlock()
        for t in tables {
            try? db.drop(table: t)
        }
    }

    // MARK: - 私有

    private func ensureTable(_ name: String) throws {
        lock.lock(); defer { lock.unlock() }
        if createdTables.contains(name) { return }
        try db.create(table: name, of: MessageModel.self)
        createdTables.insert(name)
    }
}
