import Foundation
import CryptoKit

public enum SchemaLoadError: Error {
    case http(Int)
    case sha256Mismatch(expected: String, actual: String)
}

/// 网络加载层:拉 manifest 与 schema。
/// 生产策略:**显式超时** + **绕过本地 URLCache**(reloadIgnoringLocalCacheData),
/// 避免弱网卡死或读到 app 端陈旧缓存(即便 OSS 已设 no-cache 也双保险)。
public final class SchemaLoader {
    private let session: URLSession

    public init(timeout: TimeInterval = 10) {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.timeoutIntervalForRequest = timeout
        cfg.timeoutIntervalForResource = timeout * 2
        session = URLSession(configuration: cfg)
    }

    public func fetchManifest(_ url: URL) async throws -> PageManifest {
        let (data, response) = try await session.data(for: request(url))
        try ensureOK(response)
        return try JSONDecoder().decode(PageManifest.self, from: data)
    }

    /// 拉单页 schema 并做 sha256 完整性校验。
    public func fetchSchema(url: URL, expectedSHA256: String) async throws -> Data {
        let (data, response) = try await session.data(for: request(url))
        try ensureOK(response)
        let actual = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard actual.caseInsensitiveCompare(expectedSHA256) == .orderedSame else {
            throw SchemaLoadError.sha256Mismatch(expected: expectedSHA256, actual: actual)
        }
        return data
    }

    private func request(_ url: URL) -> URLRequest {
        var r = URLRequest(url: url)
        r.cachePolicy = .reloadIgnoringLocalCacheData
        return r
    }

    private func ensureOK(_ response: URLResponse) throws {
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SchemaLoadError.http(http.statusCode)
        }
    }
}
