import Foundation

public protocol SyncServiceProtocol {
    /// - Parameter force: true 时 Mock 才吐增量;false(viewDidAppear/兜底)不打扰演示
    func fetchIncremental(after seqId: Int64, force: Bool) async throws -> SyncBatch
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

    public func fetchIncremental(after seqId: Int64, force: Bool) async throws -> SyncBatch {
        try await Task.sleep(nanoseconds: 200_000_000)  // 200ms 模拟网络

        if seqId == 0 {
            return SyncBatch(
                sessions: Self.generateMockSessions(count: 100),
                messages: [],
                maxSeqId: 100
            )
        }

        // 只有手动触发(force=true)才模拟新增量;viewDidAppear/兜底返回空 batch
        guard force else {
            return SyncBatch(sessions: [], messages: [], maxSeqId: seqId)
        }

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
