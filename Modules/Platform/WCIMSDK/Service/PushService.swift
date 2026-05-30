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

    /// 模拟服务端的"对话全局 seqId 自增器"。
    /// 真服务端会在每次 ACK 时分配比"该会话当前 max seqId"更大的新 seqId,
    /// 这里用静态计数 + lock 模拟,保证多次发送拿到的 seqId 严格递增。
    private static var serverSeqCounter: Int64 = 0
    private static let counterLock = NSLock()

    private func nextSeqId() -> Int64 {
        Self.counterLock.lock(); defer { Self.counterLock.unlock() }
        // 起点取 max(当前 sync seqId, 已用计数),保证比所有已知 seqId 大
        let base = max(WCIMSDK.seqIdManager?.currentSeqId ?? 0, Self.serverSeqCounter)
        Self.serverSeqCounter = base + 1
        return Self.serverSeqCounter
    }

    public func upload(localMsgId: String,
                       traceId: String,
                       sessionId: String,
                       contentJSON: String) async throws -> PushUploadResult {
        try await Task.sleep(nanoseconds: 500_000_000)

        if Int.random(in: 0..<10) == 0 {
            print("[Push] ❌ upload failed (localMsgId=\(localMsgId), trace=\(traceId))")
            throw PushError.networkFailed
        }

        let result = PushUploadResult(
            msgId: "srv_" + UUID().uuidString.prefix(12).lowercased(),
            seqId: nextSeqId(),
            timestamp: Int64(Date().timeIntervalSince1970)
        )
        print("[Push] ✅ ACK localMsgId=\(localMsgId) → msgId=\(result.msgId), seqId=\(result.seqId)")
        return result
    }
}
