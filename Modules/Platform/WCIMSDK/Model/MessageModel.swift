import Foundation
import WCDBSwift

public enum MessageStatus: Int {
    case sending = 0
    case sent = 1
    case failed = 2
    case received = 3
}

public enum MessageContentType: Int {
    case text = 0
    // image=1, voice=2 ...
    case card = 10   // DSL 卡片消息
}

public final class MessageModel: TableCodable, MessageEntityRef {
    public var localMsgId: String = ""    // 端上 UUID,重发不变
    public var msgId: String?              // 服务端 id,UNIQUE 去重
    public var sessionId: String = ""
    public var seqId: Int64 = 0
    public var senderId: String = ""
    public var contentType: Int = 0
    public var contentJSON: String = ""    // 各类型 payload 序列化
    public var timestamp: Int64 = 0
    public var status: Int = 0
    public var traceId: String?            // 监控追踪

    public init() {}

    public enum CodingKeys: String, CodingTableKey {
        public typealias Root = MessageModel
        case localMsgId, msgId, sessionId, seqId, senderId
        case contentType, contentJSON, timestamp, status, traceId

        public static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(localMsgId, isPrimary: true)
            BindColumnConstraint(msgId, isUnique: true)
            BindIndex(sessionId, namedWith: "_sessionId")
            BindIndex(seqId, namedWith: "_seqId")
        }
    }
}
