import Foundation
import React

/// 项目唯一的 RCTEventEmitter —— 所有原生事件都由它 emit。
/// JS 侧通过 NativeEventEmitter(NativeModules.EventBridge) 订阅。
@objc(EventBridge)
public final class EventBridge: RCTEventEmitter {

    @objc public override static func requiresMainQueueSetup() -> Bool { true }

    public override func supportedEvents() -> [String]! {
        EventRegistry.all
    }

    public override func startObserving() {
        EventBus.emitter = self
    }

    public override func stopObserving() {
        if EventBus.emitter === self {
            EventBus.emitter = nil
        }
    }

    func dispatch(topic: String, payload: [String: Any]) {
        sendEvent(withName: topic, body: payload)
    }
}
