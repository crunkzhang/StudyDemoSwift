import Foundation
import Combine
import WCIMSDK

/// 订阅 DBChangeStream.messagesPublisher(of: sessionId)。
/// 每个 ChatDetailLogic 实例各持一个 observer,按 sessionId 过滤,互不干扰。
final class MessageDBObserver {
    let changeSubject = PassthroughSubject<MessageChangeEvent, Never>()

    private let sessionId: String
    private var cancellable: AnyCancellable?

    init(sessionId: String) {
        self.sessionId = sessionId
    }

    func start() {
        cancellable = DBChangeStream.shared.messagesPublisher(of: sessionId)
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .sink { [weak self] event in
                print("[DBG][Observer-\(self?.sessionId ?? "?")] 收到 messageEvent")
                self?.changeSubject.send(event)
            }
    }

    func stop() {
        cancellable?.cancel()
        cancellable = nil
    }
}
