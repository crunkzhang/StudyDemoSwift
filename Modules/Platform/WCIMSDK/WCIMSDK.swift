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

    /// 清空当前用户的 IM 本地数据(DB 文件 + seqId)。DEBUG 用于重置 demo 状态。
    /// 调用后必须重新 setup(userId:) 才能继续使用。
    public static func clearLocalData(userId: String) {
        let dir = DBPaths.userIMDirectory(userId: userId)
        try? FileManager.default.removeItem(at: dir)
        UserDefaults.standard.removeObject(forKey: "im.seqId.\(userId)")

        currentUserId = ""
        sessionDB = nil
        messageDB = nil
        tableRegistry = nil
        seqIdManager = nil
        syncCoordinator = nil
        pushService = nil
    }
}
