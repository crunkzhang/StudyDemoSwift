import Foundation
import WCDBSwift

public final class SessionModel: TableCodable {
    public var sessionId: String = ""
    public var contactName: String = ""
    public var avatarURL: String?
    public var lastMsgId: String?
    public var lastMsgPreview: String?
    public var lastTimestamp: Int64 = 0
    public var unreadCount: Int = 0
    public var isPinned: Bool = false
    public var draft: String?
    public var extraJSON: String?

    public init() {}

    public enum CodingKeys: String, CodingTableKey {
        public typealias Root = SessionModel
        case sessionId, contactName, avatarURL
        case lastMsgId, lastMsgPreview, lastTimestamp
        case unreadCount, isPinned, draft, extraJSON

        public static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(sessionId, isPrimary: true)
            BindIndex(lastTimestamp, namedWith: "_lastTimestamp")
            BindIndex(isPinned, namedWith: "_isPinned")
        }
    }
}
