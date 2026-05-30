import Foundation

/// 端上 seqId 单点推进 — DB 事务 commit 后才调用 advance,保证消息不丢。
public final class SeqIdManager {
    private let key: String
    private let queue = DispatchQueue(label: "im.seqId.advance")
    public private(set) var currentSeqId: Int64

    public init(userId: String) {
        self.key = "im.seqId.\(userId)"
        self.currentSeqId = Int64(UserDefaults.standard.integer(forKey: key))
    }

    public func advance(to seqId: Int64) {
        queue.sync {
            guard seqId > currentSeqId else { return }
            currentSeqId = seqId
            UserDefaults.standard.set(seqId, forKey: key)
        }
    }
}
