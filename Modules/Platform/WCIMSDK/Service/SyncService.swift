import Foundation

public protocol SyncServiceProtocol {
    /// - Parameter force: true 时 Mock 才吐增量;false(viewDidAppear/兜底)不打扰演示
    func fetchIncremental(after seqId: Int64, force: Bool) async throws -> SyncBatch
}

public struct SyncBatch {
    public let sessions: [SessionModel]
    public let messages: [MessageEntityRef]
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
        try await Task.sleep(nanoseconds: 200_000_000)

        if seqId == 0 {
            // 首次同步:每个会话生成 3~10 条历史消息;session 的 lastMsg* 从最后一条派生
            return Self.bootstrapBatch(sessionCount: 100)
        }

        // 只有手动触发才模拟新增量;否则返回空 batch
        guard force else {
            return SyncBatch(sessions: [], messages: [], maxSeqId: seqId)
        }

        // 增量:随机挑 1~3 个会话,每个会话来一条对方新消息
        return Self.incrementalBatch(startSeqId: seqId, count: Int.random(in: 1...3))
    }

    // MARK: - Mock 数据池

    private static let names = ["张伟", "王芳", "李娜", "刘洋", "陈静", "杨帆",
                                "赵磊", "黄丽", "周杰", "吴敏"]
    private static let texts = ["你好", "在吗?", "今晚一起吃饭", "好的,收到", "晚安🌙",
                                "明天见", "周末爬山", "刚到家", "哈哈哈哈", "已读",
                                "刚刚有点事", "马上到", "等会再说", "OK", "嗯嗯",
                                "知道了", "辛苦了", "早安☀️", "happy birthday 🎂", "👌"]
    private static let avatarURLs = [
        "https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=240&q=80",
        "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=240&q=80",
        "https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=240&q=80",
        "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=240&q=80",
        "https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=240&q=80",
        "https://images.unsplash.com/photo-1488426862026-3ee34a7d66df?auto=format&fit=crop&w=240&q=80",
        "https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=240&q=80",
        "https://images.unsplash.com/photo-1502685104226-ee32379fefbe?auto=format&fit=crop&w=240&q=80",
        "https://images.unsplash.com/photo-1504593811423-6dd665756598?auto=format&fit=crop&w=240&q=80",
        "https://images.unsplash.com/photo-1502323777036-f29e3972d82f?auto=format&fit=crop&w=240&q=80",
    ]

    private static let myUserId = "mock_local_user"

    /// 根据 sessionId 稳定取 avatarURL(同一个 session 每次都拿同一张)
    private static func avatarURL(for sessionId: String) -> String {
        let sum = sessionId.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return avatarURLs[abs(sum) % avatarURLs.count]
    }

    // MARK: - 批量构造

    /// 首次同步包(seqId=0 → 100 会话 × 3~10 条消息)
    public static func bootstrapBatch(sessionCount: Int) -> SyncBatch {
        let nowTs = Int64(Date().timeIntervalSince1970)
        var sessions: [SessionModel] = []
        var messages: [MessageModel] = []
        var seqId: Int64 = 0

        for i in 0..<sessionCount {
            let sessionId = "mock_session_\(i)"
            let peerId = "peer_\(i)"
            let msgCount = Int.random(in: 3...10)

            // 会话的"基准时间" — 越靠后的会话越老(spread on time axis)
            let sessionBaseTs = nowTs - Int64(i * 600)

            var msgsOfSession: [MessageModel] = []
            for j in 0..<msgCount {
                seqId += 1
                let m = MessageModel()
                m.localMsgId = "mock_\(sessionId)_\(j)"
                m.msgId = "srv_\(sessionId)_\(j)"
                m.sessionId = sessionId
                m.seqId = seqId
                // 交替:偶数索引对方发的,奇数索引我发的
                m.senderId = (j % 2 == 0) ? peerId : myUserId
                m.contentType = MessageContentType.text.rawValue
                m.contentJSON = encodeText(texts[(i + j) % texts.count])
                // 越靠后的消息越新
                m.timestamp = sessionBaseTs - Int64((msgCount - j - 1) * 60)
                m.status = (m.senderId == myUserId)
                    ? MessageStatus.sent.rawValue
                    : MessageStatus.received.rawValue
                msgsOfSession.append(m)
            }

            messages.append(contentsOf: msgsOfSession)

            // session 字段从最后一条消息派生
            let last = msgsOfSession.last!
            let s = SessionModel()
            s.sessionId = sessionId
            s.contactName = "\(names[i % names.count])\(i)"
            s.avatarURL = Self.avatarURL(for: sessionId)
            s.lastMsgId = last.msgId
            s.lastMsgPreview = decodeTextPreview(last.contentJSON)
            s.lastTimestamp = last.timestamp
            s.unreadCount = (i % 7 == 0) ? Int.random(in: 1...9) : 0
            s.isPinned = i < 3
            sessions.append(s)
        }

        return SyncBatch(sessions: sessions, messages: messages, maxSeqId: seqId)
    }

    /// 增量同步包(force=true 时挑 count 个会话,每个来一条对方新消息)
    public static func incrementalBatch(startSeqId: Int64, count: Int) -> SyncBatch {
        let nowTs = Int64(Date().timeIntervalSince1970)
        var sessions: [SessionModel] = []
        var messages: [MessageModel] = []
        var seqId = startSeqId

        for k in 0..<count {
            seqId += 1
            let idx = Int.random(in: 0..<100)
            let sessionId = "mock_session_\(idx)"
            let peerId = "peer_\(idx)"

            let m = MessageModel()
            m.localMsgId = "mock_inc_\(seqId)"
            m.msgId = "srv_inc_\(seqId)"
            m.sessionId = sessionId
            m.seqId = seqId
            m.senderId = peerId  // 增量都是对方发来的
            m.contentType = MessageContentType.text.rawValue
            m.contentJSON = encodeText(texts[Int.random(in: 0..<texts.count)])
            m.timestamp = nowTs + Int64(k)  // 微调时间戳保证顺序
            m.status = MessageStatus.received.rawValue
            messages.append(m)

            // 同步更新 session(从消息派生)
            // 未读 +1 由 SyncCoordinator 端兜底处理较复杂,这里 Mock 简化:每次 +1
            let existingUnread = WCIMSDK.sessionDB?
                .fetch(sessionIds: [sessionId])
                .first?.unreadCount ?? 0

            let s = SessionModel()
            s.sessionId = sessionId
            s.contactName = "\(names[idx % names.count])\(idx)"
            s.avatarURL = Self.avatarURL(for: sessionId)
            s.lastMsgId = m.msgId
            s.lastMsgPreview = decodeTextPreview(m.contentJSON)
            s.lastTimestamp = m.timestamp
            s.unreadCount = existingUnread + 1
            s.isPinned = idx < 3
            sessions.append(s)
        }

        return SyncBatch(sessions: sessions, messages: messages, maxSeqId: seqId)
    }

    // MARK: - Helpers

    private static func encodeText(_ text: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: ["text": text]),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private static func decodeTextPreview(_ json: String) -> String {
        guard let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let text = dict["text"] as? String else {
            return ""
        }
        return text
    }
}
