import Foundation
import CommonCrypto

/// sessionId 由服务端下发,格式多样(uid-uid / g_xxx / UUID 等)。
/// 表名走 SHA1 截取保证:长度固定 24 字符内、绝对防 SQL 注入、兼容任意格式。
public final class MessageTableNameRegistry {

    private var cache: [String: String] = [:]
    private let lock = NSLock()

    public init() {}

    public func tableName(for sessionId: String) -> String {
        lock.lock(); defer { lock.unlock() }
        if let cached = cache[sessionId] { return cached }
        let name = "message_" + Self.sha1Prefix16(sessionId)
        cache[sessionId] = name
        return name
    }

    private static func sha1Prefix16(_ input: String) -> String {
        let data = Data(input.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes { buf in
            _ = CC_SHA1(buf.baseAddress, CC_LONG(data.count), &digest)
        }
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(16))
    }
}
