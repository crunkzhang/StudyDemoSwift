import Foundation
import WCIMSDK

/// 喂给 TextMessageCell 的 UI 数据模型。Hashable 给 DiffableDataSource diff。
public struct MessageCellModel: Hashable {
    public let localMsgId: String
    public let msgId: String?
    public let sessionId: String
    public let senderId: String
    public let isFromMe: Bool       // 视觉:我发的右侧绿,对方左侧白
    public let text: String
    public let timestamp: Int64
    public let status: MessageStatus

    public init(localMsgId: String, msgId: String?, sessionId: String,
                senderId: String, isFromMe: Bool, text: String,
                timestamp: Int64, status: MessageStatus) {
        self.localMsgId = localMsgId
        self.msgId = msgId
        self.sessionId = sessionId
        self.senderId = senderId
        self.isFromMe = isFromMe
        self.text = text
        self.timestamp = timestamp
        self.status = status
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
    }
}
