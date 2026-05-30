import Foundation

public protocol SyncServiceProtocol {
    func fetchIncremental(after seqId: Int64) async throws -> SyncBatch
}

public struct SyncBatch {
    public let sessions: [SessionModel]
    public let messages: [MessageEntityRef]   // Phase 1 空数组,Phase 2 接入
    public let maxSeqId: Int64

    public init(sessions: [SessionModel], messages: [MessageEntityRef], maxSeqId: Int64) {
        self.sessions = sessions
        self.messages = messages
        self.maxSeqId = maxSeqId
    }
}

public final class MockSyncService: SyncServiceProtocol {
    public init() {}

    public func fetchIncremental(after seqId: Int64) async throws -> SyncBatch {
        try await Task.sleep(nanoseconds: 200_000_000)  // 200ms 模拟网络

        if seqId == 0 {
            // 首次同步:吐 100 条假会话
            return SyncBatch(
                sessions: Self.generateMockSessions(count: 100),
                messages: [],
                maxSeqId: 100
            )
        }

        // 增量:随机更新 1~3 条
        let updateCount = Int.random(in: 1...3)
        let now = Int64(Date().timeIntervalSince1970)
        let sessions: [SessionModel] = (0..<updateCount).map { _ in
            let idx = Int.random(in: 0..<100)
            return Self.makeSession(index: idx, baseTimestamp: now)
        }
        return SyncBatch(sessions: sessions, messages: [], maxSeqId: seqId + Int64(updateCount))
    }

    // MARK: - Mock 数据

    private static let names = ["张伟", "王芳", "李娜", "刘洋", "陈静", "杨帆",
                                "赵磊", "黄丽", "周杰", "吴敏"]
    private static let messages = ["你好", "在吗?", "[图片]", "今晚一起吃饭",
                                   "好的,收到", "[文件]", "晚安🌙", "明天见",
                                   "周末爬山", "刚到家"]

    public static func generateMockSessions(count: Int) -> [SessionModel] {
        let now = Int64(Date().timeIntervalSince1970)
        return (0..<count).map { i in
            makeSession(index: i, baseTimestamp: now - Int64(i * 600))
        }
    }

    private static func makeSession(index i: Int, baseTimestamp: Int64) -> SessionModel {
        let m = SessionModel()
        m.sessionId = "mock_session_\(i)"
        m.contactName = "\(names[i % names.count])\(i)"
        m.lastMsgPreview = messages[i % messages.count]
        m.lastTimestamp = baseTimestamp
        m.unreadCount = i % 7 == 0 ? Int.random(in: 1...99) : 0
        m.isPinned = i < 3
        return m
    }
}
