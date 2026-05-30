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
    /// 不销毁 DB 实例 — 业务侧 logic 持有的 db 引用仍然有效;
    /// 只清表数据 + seqId + 重建 syncCoordinator(它持有旧 seqIdManager)。
    public static func clearLocalData() {
        try? sessionDB?.wipeAll()
        try? messageDB?.wipeAll()
        tableRegistry = MessageTableNameRegistry()   // 表名缓存清掉

        let key = "im.seqId.\(currentUserId)"
        UserDefaults.standard.removeObject(forKey: key)

        // 重建 seqIdManager(从空 UserDefaults 读到 0)+ 重建 syncCoordinator(持有 seqIdManager 引用)
        guard let sdb = sessionDB, let mdb = messageDB else { return }
        let seq = SeqIdManager(userId: currentUserId)
        seqIdManager = seq
        syncCoordinator = SyncCoordinator(
            service: MockSyncService(),
            sessionDB: sdb,
            messageDB: mdb,
            seqIdManager: seq
        )
    }
}
