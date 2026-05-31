import Foundation
import CryptoKit

public enum PageSchemaError: Error {
    case networkFailed(Int)
    case sha256Mismatch(expected: String, actual: String)
}

/// 下载单个 schema JSON 并做 sha256 校验(比游戏简单:无 zip,直接拿文本)。
public final class PageSchemaDownloader {
    private let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }

    public func download(url: URL, expectedSHA256: String) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw PageSchemaError.networkFailed(http.statusCode)
        }
        let actual = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        guard actual.lowercased() == expectedSHA256.lowercased() else {
            throw PageSchemaError.sha256Mismatch(expected: expectedSHA256, actual: actual)
        }
        return data
    }
}
