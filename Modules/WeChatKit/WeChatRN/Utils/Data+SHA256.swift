import Foundation
import CommonCrypto

extension Data {
    var sha256Digest: [UInt8] {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        withUnsafeBytes { bytes in
            _ = CC_SHA256(bytes.baseAddress, CC_LONG(count), &digest)
        }
        return digest
    }

    var sha256String: String {
        sha256Digest.map { String(format: "%02x", $0) }.joined()
    }
}
