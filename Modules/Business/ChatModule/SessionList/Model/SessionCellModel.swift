import Foundation

/// 喂给 SessionListCell 的 UI 数据模型。Hashable 给 DiffableDataSource diff 用。
public struct SessionCellModel: Hashable {
    public let sessionId: String
    public let contactName: String
    public let avatarURL: String?
    public let lastMsgPreview: String
    public let formattedTime: String
    public let unreadCount: Int
    public let isPinned: Bool
    public let lastTimestamp: Int64

    public init(sessionId: String, contactName: String, avatarURL: String?,
                lastMsgPreview: String, formattedTime: String,
                unreadCount: Int, isPinned: Bool, lastTimestamp: Int64) {
        self.sessionId = sessionId
        self.contactName = contactName
        self.avatarURL = avatarURL
        self.lastMsgPreview = lastMsgPreview
        self.formattedTime = formattedTime
        self.unreadCount = unreadCount
        self.isPinned = isPinned
        self.lastTimestamp = lastTimestamp
    }

    /// hash 只用主键 sessionId — DiffableDataSource 用此判断"是不是同一行"
    public func hash(into h: inout Hasher) {
        h.combine(sessionId)
    }

    /// == 比所有展示字段 — 任一字段变 → diff 算出 reload/reconfigure
    public static func == (l: Self, r: Self) -> Bool {
        l.sessionId == r.sessionId
            && l.contactName == r.contactName
            && l.avatarURL == r.avatarURL
            && l.lastMsgPreview == r.lastMsgPreview
            && l.formattedTime == r.formattedTime
            && l.unreadCount == r.unreadCount
            && l.isPinned == r.isPinned
            && l.lastTimestamp == r.lastTimestamp
    }
}
