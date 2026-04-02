import Foundation
import React

protocol BridgeSignalProvider {
    static var bridgeSignals: [String] { get }
}

class RNBridge: RCTEventEmitter {
    @objc
    override static func requiresMainQueueSetup() -> Bool {
        true
    }

    override func supportedEvents() -> [String]! {
        if let signalProvider = type(of: self) as? BridgeSignalProvider.Type {
            return signalProvider.bridgeSignals
        }
        return []
    }

    override func startObserving() {
        RNBridgeContext.shared.eventEmitter = self
    }

    override func stopObserving() {
    }

    func executeOnMain(_ work: @escaping () -> Void) {
        DispatchQueue.main.async(execute: work)
    }

    func activateEventEmitter() {
        RNBridgeContext.shared.eventEmitter = self
    }
}
