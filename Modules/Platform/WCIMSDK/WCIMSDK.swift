import Foundation

/// IM 通用基础设施入口。所有 DB / Service 必须在 setup(userId:) 后才能访问。
public enum WCIMSDK {
    public private(set) static var currentUserId: String = ""

    public static func setup(userId: String) {
        currentUserId = userId
        // 后续 Task 在此处初始化 SessionDB / MessageDB / SeqIdManager / SyncCoordinator
    }
}
