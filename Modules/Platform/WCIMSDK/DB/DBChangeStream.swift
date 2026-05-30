import Foundation
import Combine

public enum SessionChangeEvent {
    case insert([String])
    case update([String])
    case delete([String])
}

public enum MessageChangeEvent {
    case insert(sessionId: String, messages: [MessageEntityRef])
    case update(sessionId: String, messages: [MessageEntityRef])
    case delete(sessionId: String, localMsgIds: [String])
}

/// MessageModel 在 Phase 2 落地。Phase 1 用 protocol 解耦,避免双向依赖。
public protocol MessageEntityRef {
    var localMsgId: String { get }
    var sessionId: String { get }
}

/// 写入侧主动广播 — DB 层事务 commit 后调用 publish(...),业务侧通过 publisher 订阅。
public final class DBChangeStream {
    public static let shared = DBChangeStream()
    private init() {}

    private let sessionSubject = PassthroughSubject<SessionChangeEvent, Never>()
    private let messageSubject = PassthroughSubject<(sessionId: String, event: MessageChangeEvent), Never>()

    public var sessionsPublisher: AnyPublisher<SessionChangeEvent, Never> {
        sessionSubject.eraseToAnyPublisher()
    }

    /// 按 sessionId 过滤,每个 ChatDetailLogic 各订各的。
    public func messagesPublisher(of sessionId: String) -> AnyPublisher<MessageChangeEvent, Never> {
        messageSubject
            .filter { $0.sessionId == sessionId }
            .map { $0.event }
            .eraseToAnyPublisher()
    }

    public func publish(session event: SessionChangeEvent) {
        sessionSubject.send(event)
    }

    public func publish(message event: MessageChangeEvent, sessionId: String) {
        messageSubject.send((sessionId, event))
    }
}
