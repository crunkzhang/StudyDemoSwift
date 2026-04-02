import UIKit
import React

final class RNBridgeContext {
    static let shared = RNBridgeContext()

    weak var currentViewController: UIViewController?
    weak var eventEmitter: RCTEventEmitter?

    private init() {}

    func emit(signal: String, payload: [String: Any]) {
        eventEmitter?.sendEvent(withName: signal, body: payload)
    }
}
