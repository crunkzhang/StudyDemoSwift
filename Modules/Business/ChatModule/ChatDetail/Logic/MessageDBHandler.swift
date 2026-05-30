import UIKit
import WCIMSDK

final class MessageDBHandler {
    private let db: MessageDB
    private let sessionId: String
    private let myUserId: String
    private let renderCache: MessageRenderCache

    init(db: MessageDB, sessionId: String, myUserId: String,
         renderCache: MessageRenderCache) {
        self.db = db
        self.sessionId = sessionId
        self.myUserId = myUserId
        self.renderCache = renderCache
    }

    func fetchPage(beforeSeqId: Int64? = nil, limit: Int = 50) -> [MessageCellModel] {
        let raw = db.fetchPage(sessionId: sessionId, beforeSeqId: beforeSeqId, limit: limit)

        // 混合排序:
        // 1. 已 ACK 消息(seqId > 0) → 按 seqId 升序(服务端保证单调递增)
        // 2. pending 消息(seqId = 0,server 未分配) → 排到尾部,按 timestamp 升序(发送顺序)
        // ACK 回填后 seqId 由 0 变成 server 分配的新 max,自然归位到序列末尾,
        // 视觉上"还是在最底下",顺序稳定不闪。
        let sortedRaw = raw.sorted { lhs, rhs in
            let lHasSeq = lhs.seqId > 0
            let rHasSeq = rhs.seqId > 0
            if lHasSeq != rHasSeq {
                return lHasSeq                       // 有 seqId 的在前,pending 在后
            }
            if lHasSeq {
                if lhs.seqId != rhs.seqId {
                    return lhs.seqId < rhs.seqId     // 都有 seqId → 按 seqId 升序
                }
                return lhs.timestamp < rhs.timestamp // seqId 相等(异常防御)→ 按时间升序
            }
            return lhs.timestamp < rhs.timestamp     // 都没 seqId → 按发送时间升序
        }

        let models = sortedRaw.map(toCellModel)
        // 后台批量预算高度,主线程零计算
        DispatchQueue.global(qos: .userInitiated).async { [renderCache] in
            Self.precalculate(models: models, cache: renderCache)
        }
        return models
    }

    func toCellModel(_ m: MessageModel) -> MessageCellModel {
        let content = MessageContent(jsonString: m.contentJSON)
        return MessageCellModel(
            localMsgId: m.localMsgId,
            msgId: m.msgId,
            sessionId: m.sessionId,
            senderId: m.senderId,
            isFromMe: m.senderId == myUserId,
            text: content.displayText,
            timestamp: m.timestamp,
            status: MessageStatus(rawValue: m.status) ?? .received
        )
    }

    // MARK: - 高度预算

    /// 必须和 TextMessageCell 的布局保持一致:气泡 maxWidth=260,内 padding 12+12,
    /// 文字 16pt,上下气泡间距 12(top 6 + bottom 6)。
    private static let bubbleMaxWidth: CGFloat = 260
    private static let bubbleHPadding: CGFloat = 12 + 12
    private static let bubbleVPadding: CGFloat = 10 + 10
    private static let rowVMargin: CGFloat = 6 + 6
    private static let textFont = UIFont.systemFont(ofSize: 16)

    private static func precalculate(models: [MessageCellModel], cache: MessageRenderCache) {
        let contentWidth = bubbleMaxWidth - bubbleHPadding
        for m in models {
            guard cache.height(for: m.localMsgId) == nil else { continue }
            let rect = (m.text as NSString).boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: textFont],
                context: nil
            )
            let height = ceil(rect.height) + bubbleVPadding + rowVMargin
            cache.cache(height: height, attributedText: nil, for: m.localMsgId)
        }
    }
}
