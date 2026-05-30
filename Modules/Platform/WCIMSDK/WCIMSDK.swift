import Foundation

/// IM 通用基础设施入口。所有 DB / Service 必须在 setup(userId:) 后才能访问。
public enum WCIMSDK {
    public private(set) static var currentUserId: String = ""
    public private(set) static var sessionDB: SessionDB?
    public private(set) static var seqIdManager: SeqIdManager?

    public static func setup(userId: String) {
        currentUserId = userId
        sessionDB = SessionDB(userId: userId)
        seqIdManager = SeqIdManager(userId: userId)
    }
}
