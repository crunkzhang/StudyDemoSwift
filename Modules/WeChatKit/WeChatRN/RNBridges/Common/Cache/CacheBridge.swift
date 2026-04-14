import Foundation

@objc(CacheBridge)
final class CacheBridge: NSObject {

    @objc static func requiresMainQueueSetup() -> Bool { false }

    private let defaults = UserDefaults.standard
    private static let namespace = "WeChatRN.Cache."

    private func fullKey(_ key: String) -> String { Self.namespace + key }

    @objc func getString(_ key: String) -> NSString? {
        defaults.string(forKey: fullKey(key)) as NSString?
    }

    @objc func getBool(_ key: String) -> NSNumber {
        NSNumber(value: defaults.bool(forKey: fullKey(key)))
    }

    @objc func getNumber(_ key: String) -> NSNumber {
        NSNumber(value: defaults.double(forKey: fullKey(key)))
    }

    @objc func setString(_ key: String, value: String) {
        defaults.set(value, forKey: fullKey(key))
    }

    @objc func setBool(_ key: String, value: Bool) {
        defaults.set(value, forKey: fullKey(key))
    }

    @objc func setNumber(_ key: String, value: Double) {
        defaults.set(value, forKey: fullKey(key))
    }

    @objc func remove(_ key: String) {
        defaults.removeObject(forKey: fullKey(key))
    }
}
