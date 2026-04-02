import Foundation

private enum ToastBridgeSignals {
    static let didShow = "toastBridge:didShow"
    static let all = [didShow]
}

struct ToastParams: Decodable {
    let message: String
    let duration: Double?

    var resolvedDuration: TimeInterval {
        duration ?? 1.8
    }
}

@objc(ToastBridge)
final class ToastBridge: RNBridge, BridgeSignalProvider {
    static let bridgeSignals = ToastBridgeSignals.all

    @objc(show:)
    func show(_ params: [String: Any]) {
        executeOnMain {
            self.activateEventEmitter()
            guard let toastParams = BridgeDecode.decode(ToastParams.self, from: params),
                  !toastParams.message.isEmpty else {
                return
            }
            ToastBridgeHandler.shared.show(message: toastParams.message, duration: toastParams.resolvedDuration)
        }
    }
}
