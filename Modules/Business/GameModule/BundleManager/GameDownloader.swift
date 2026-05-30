import Foundation
import CryptoKit
import ZIPFoundation

public enum GameDownloadError: Error {
    case networkFailed(Error?)
    case sha256Mismatch(expected: String, actual: String)
    case unzipFailed(Error)
}

public final class GameDownloader {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// 下载 zip → SHA256 校验 → 解压到 destination 目录(覆盖已存在)
    public func download(url: URL,
                         expectedSHA256: String,
                         destination: URL) async throws {
        // 1. 下载到临时文件
        let (tmpURL, response) = try await session.download(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw GameDownloadError.networkFailed(
                NSError(domain: "GameDownloader", code: http.statusCode)
            )
        }

        // 2. SHA256 校验
        let data = try Data(contentsOf: tmpURL)
        let actual = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        guard actual.lowercased() == expectedSHA256.lowercased() else {
            try? FileManager.default.removeItem(at: tmpURL)
            throw GameDownloadError.sha256Mismatch(expected: expectedSHA256, actual: actual)
        }

        // 3. 准备 destination(清空旧的)
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)

        // 4. ZIPFoundation 解压
        do {
            try fm.unzipItem(at: tmpURL, to: destination)
        } catch {
            try? fm.removeItem(at: destination)
            throw GameDownloadError.unzipFailed(error)
        }

        // 5. 清理临时文件
        try? fm.removeItem(at: tmpURL)
    }
}
