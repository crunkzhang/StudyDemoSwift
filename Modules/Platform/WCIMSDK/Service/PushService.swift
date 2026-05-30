import Foundation

public struct PushUploadResult {
    public let msgId: String
    public let seqId: Int64
    public let timestamp: Int64
}

public enum PushError: Error {
    case networkFailed
}

public protocol PushServiceProtocol {
    func upload(localMsgId: String,
                traceId: String,
                sessionId: String,
                contentJSON: String) async throws -> PushUploadResult
}

/// Mock 上行:500ms 模拟网络 + 10% 失败率。
public final class MockPushService: PushServiceProtocol {
    public init() {}

    public func upload(localMsgId: String,
                       traceId: String,
                       sessionId: String,
                       contentJSON: String) async throws -> PushUploadResult {
        try await Task.sleep(nanoseconds: 500_000_000)

        if Int.random(in: 0..<10) == 0 {
            print("[Push] ❌ upload failed (localMsgId=\(localMsgId), trace=\(traceId))")
            throw PushError.networkFailed
        }

        let seq = (WCIMSDK.seqIdManager?.currentSeqId ?? 0) + 1
        let result = PushUploadResult(
            msgId: "srv_" + UUID().uuidString.prefix(12).lowercased(),
            seqId: seq,
            timestamp: Int64(Date().timeIntervalSince1970)
        )
        print("[Push] ✅ ACK localMsgId=\(localMsgId) → msgId=\(result.msgId), seqId=\(result.seqId)")
        return result
    }
}
