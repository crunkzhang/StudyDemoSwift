import Foundation
import Combine
import WCIMSDK

/// 聊天详情页业务逻辑(per session 实例)。
/// 协调 MessageDBHandler / MessageDBObserver / SendMsgHandler。
public final class ChatDetailLogic {
    @Published public private(set) var messages: [MessageCellModel] = []
    public let renderCache = MessageRenderCache()

    public let sessionId: String
    public let contactName: String

    private let handler: MessageDBHandler
    private let observer: MessageDBObserver
    private let sender: SendMsgHandler
    private var cancellable: AnyCancellable?

    public init(sessionId: String, contactName: String) {
        guard let db = WCIMSDK.messageDB else {
            fatalError("WCIMSDK.setup must be called before ChatDetailLogic.init")
        }
        self.sessionId = sessionId
        self.contactName = contactName
        self.handler = MessageDBHandler(
            db: db, sessionId: sessionId,
            myUserId: WCIMSDK.currentUserId,
            renderCache: renderCache
        )
        self.observer = MessageDBObserver(sessionId: sessionId)
        self.sender = SendMsgHandler(sessionId: sessionId, myUserId: WCIMSDK.currentUserId)
    }

    public func start() {
        reload()
        observer.start()
        cancellable = observer.changeSubject
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .sink { [weak self] _ in
                print("[DBG][Logic-\(self?.sessionId ?? "?")] observer 触发 reload")
                self?.reload()
            }
    }

    public func stop() {
        cancellable?.cancel()
        observer.stop()
    }

    // MARK: - 命令

    public func send(_ text: String) async {
        await sender.send(text: text)
    }

    public func retry(_ localMsgId: String) async {
        await sender.retry(localMsgId: localMsgId)
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
        let statuses = page.map { "\($0.localMsgId.prefix(6))=\($0.status)" }.joined(separator: ",")
        print("[DBG][Logic-\(sessionId)] reload → \(page.count) 条, statuses=[\(statuses)]")
        DispatchQueue.main.async { [weak self] in
            self?.messages = page
        }
    }
}
