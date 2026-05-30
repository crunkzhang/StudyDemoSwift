import Foundation

/// IM 通用基础设施入口。所有 DB / Service 必须在 setup(userId:) 后才能访问。
public enum WCIMSDK {
    public private(set) static var currentUserId: String = ""
    public private(set) static var sessionDB: SessionDB?
    public private(set) static var messageDB: MessageDB?
    public private(set) static var tableRegistry: MessageTableNameRegistry?
    public private(set) static var seqIdManager: SeqIdManager?
    public private(set) static var syncCoordinator: SyncCoordinator?
    public private(set) static var pushService: PushServiceProtocol?

    public static func setup(userId: String) {
        currentUserId = userId
        let reg = MessageTableNameRegistry()
        let sdb = SessionDB(userId: userId)
        let mdb = MessageDB(userId: userId, registry: reg)
        let seq = SeqIdManager(userId: userId)
        tableRegistry = reg
        sessionDB = sdb
        messageDB = mdb
        seqIdManager = seq
        syncCoordinator = SyncCoordinator(
            service: MockSyncService(),
            sessionDB: sdb,
            messageDB: mdb,
            seqIdManager: seq
        )
        pushService = MockPushService()
    }

    /// 清空当前用户的 IM 本地数据(DEBUG 用)。
    /// 不销毁 DB 实例(业务侧 logic 持有的引用仍然有效),也不重置 seqId —
    /// 这样下次手动 sync 不会触发首次 bootstrap 灌入 100 会话,而是按增量
    /// 路径每次只来 1~3 条新消息。
    public static func clearLocalData() {
        try? sessionDB?.wipeAll()
        try? messageDB?.wipeAll()
        tableRegistry = MessageTableNameRegistry()
    }
}
