import Foundation
import WCIMSDK

/// 喂给消息 cell 的 UI 数据模型。Hashable 给 DiffableDataSource diff。
public struct MessageCellModel: Hashable {
    /// 渲染类型:决定用哪种 cell
    public enum Kind: Hashable { case text, card }

    public let localMsgId: String
    public let msgId: String?
    public let sessionId: String
    public let senderId: String
    public let isFromMe: Bool       // 视觉:我发的右侧绿,对方左侧白
    public let text: String
    public let timestamp: Int64
    public let status: MessageStatus
    public let kind: Kind
    /// 卡片 payload(kind == .card 时有值)
    public let cardJSON: String?

    public init(localMsgId: String, msgId: String?, sessionId: String,
                senderId: String, isFromMe: Bool, text: String,
                timestamp: Int64, status: MessageStatus,
                kind: Kind = .text, cardJSON: String? = nil) {
        self.localMsgId = localMsgId
        self.msgId = msgId
        self.sessionId = sessionId
        self.senderId = senderId
        self.isFromMe = isFromMe
        self.text = text
        self.timestamp = timestamp
        self.status = status
        self.kind = kind
        self.cardJSON = cardJSON
    }

    public func hash(into h: inout Hasher) {
        h.combine(localMsgId)
    }

    public static func == (l: Self, r: Self) -> Bool {
        l.localMsgId == r.localMsgId
            && l.msgId == r.msgId
            && l.text == r.text
            && l.timestamp == r.timestamp
            && l.status == r.status
            && l.kind == r.kind
            && l.cardJSON == r.cardJSON
    }
}
