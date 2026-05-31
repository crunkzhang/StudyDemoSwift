import Foundation
import Security

/// 极简 Keychain 封装,按 vendor 分别存取各家 AI 的 API Key。
/// API Key 绝不进 bundle / 源码 / JS。
public enum KeychainAIKey {
    private static let service = "com.study.wcSwift.ai"
    private static func account(_ vendor: String) -> String { "ai.key.\(vendor)" }

    public static func load(_ vendor: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(vendor),
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    public static func save(_ key: String, vendor: String) -> Bool {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account(vendor)
        ]
        SecItemDelete(base as CFDictionary)
        var attrs = base
        attrs[kSecValueData as String] = key.data(using: .utf8)
        return SecItemAdd(attrs as CFDictionary, nil) == errSecSuccess
    }
}
