import Foundation
import Combine
import WCIMSDK

/// 聊天详情页业务逻辑(per session 实例)。
/// 协调 MessageDBHandler / SendMsgHandler,直接订阅 DBChangeStream。
public final class ChatDetailLogic {
    @Published public private(set) var messages: [MessageCellModel] = []
    public let renderCache: MessageRenderCache

    public let sessionId: String
    public let contactName: String

    private let handler: MessageDBHandler
    private let sender: SendMsgHandler
    private var cancellable: AnyCancellable?

    /// P0:依赖注入 — 测试时可传 mock MessageDB,默认走 WCIMSDK 实例。
    public init(sessionId: String,
                contactName: String,
                db: MessageDB? = WCIMSDK.messageDB) {
        guard let db = db else {
            fatalError("ChatDetailLogic 初始化时 MessageDB 为 nil — 请先 WCIMSDK.setup")
        }
        self.sessionId = sessionId
        self.contactName = contactName
        let cache = MessageRenderCache()
        self.renderCache = cache
        self.handler = MessageDBHandler(
            db: db, sessionId: sessionId,
            myUserId: WCIMSDK.currentUserId,
            renderCache: cache
        )
        self.sender = SendMsgHandler(sessionId: sessionId, myUserId: WCIMSDK.currentUserId)
    }

    public func start() {
        reload()
        // P0:直接订阅 DBChangeStream,删除 MessageDBObserver 中转层
        cancellable = DBChangeStream.shared.messagesPublisher(of: sessionId)
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .sink { [weak self] _ in self?.reload() }
    }

    public func stop() {
        cancellable?.cancel()
    }

    // MARK: - 命令

    /// 同步入口 — 写 DB sending 立刻返回,UI 即时刷新;上行后台 actor 串行跑。
    public func send(_ text: String) {
        sender.send(text: text)
    }

    public func retry(_ localMsgId: String) {
        sender.retry(localMsgId: localMsgId)
    }

    /// 标该会话所有消息为已读 — VC viewDidAppear 调用,
    /// SessionDB.unreadCount 清零并广播,SessionList 红点消失。
    public func markAllRead() {
        guard let sdb = WCIMSDK.sessionDB,
              let s = sdb.fetch(sessionIds: [sessionId]).first,
              s.unreadCount > 0 else { return }
        do {
            try sdb.runTransaction { [sessionId] in
                s.unreadCount = 0
                try sdb.upsert([s])
            }
            DBChangeStream.shared.publish(session: .update([sessionId]))
        } catch {
            print("[ChatDetail] markAllRead failed: \(error)")
        }
    }

    // MARK: - 私有

    private func reload() {
        let page = handler.fetchPage(beforeSeqId: nil, limit: 50)
        DispatchQueue.main.async { [weak self] in
            self?.messages = page
        }
    }
}
