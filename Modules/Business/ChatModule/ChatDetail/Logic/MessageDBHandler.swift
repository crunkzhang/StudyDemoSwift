import Foundation
import WCIMSDK

final class MessageDBHandler {
    private let db: MessageDB
    private let sessionId: String
    private let myUserId: String

    init(db: MessageDB, sessionId: String, myUserId: String) {
        self.db = db
        self.sessionId = sessionId
        self.myUserId = myUserId
    }

    func fetchPage(beforeSeqId: Int64? = nil, limit: Int = 50) -> [MessageCellModel] {
        let raw = db.fetchPage(sessionId: sessionId, beforeSeqId: beforeSeqId, limit: limit)
        // DB 返回是 seqId 倒序(最新在前),UI 显示要时间正序,反一下
        return raw.reversed().map(toCellModel)
    }

    func toCellModel(_ m: MessageModel) -> MessageCellModel {
        let payload = (try? JSONDecoder().decode([String: String].self,
                                                 from: Data(m.contentJSON.utf8))) ?? [:]
        return MessageCellModel(
            localMsgId: m.localMsgId,
            msgId: m.msgId,
            sessionId: m.sessionId,
            senderId: m.senderId,
            isFromMe: m.senderId == myUserId,
            text: payload["text"] ?? "",
            timestamp: m.timestamp,
            status: MessageStatus(rawValue: m.status) ?? .received
        )
    }
}
