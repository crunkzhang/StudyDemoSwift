import Foundation
import Security

/// 极简 Keychain 封装,仅用于存取 AI provider 的 API Key。
/// API Key 绝不进 bundle / 源码 / JS。
public enum KeychainAIKey {
    private static let account = "ai.anthropic.apiKey"
    private static let service = "com.study.wcSwift.ai"

    public static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    public static func save(_ key: String) -> Bool {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(base as CFDictionary)
        var attrs = base
        attrs[kSecValueData as String] = key.data(using: .utf8)
        return SecItemAdd(attrs as CFDictionary, nil) == errSecSuccess
    }
}
