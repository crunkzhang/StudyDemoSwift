import Foundation
import Combine
import WCIMSDK

/// 订阅 DBChangeStream.sessions,转发到 changeSubject 供 Logic 消费
final class SessionDBObserver {
    let changeSubject = PassthroughSubject<SessionChangeEvent, Never>()

    private var cancellable: AnyCancellable?

    func start() {
        cancellable = DBChangeStream.shared.sessionsPublisher
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .sink { [weak self] event in
                self?.changeSubject.send(event)
            }
    }

    func stop() {
        cancellable?.cancel()
        cancellable = nil
    }
}
