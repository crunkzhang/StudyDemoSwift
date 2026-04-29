import Foundation

public enum CatonType: String, Codable {
    case runLoop
    case fps
    case watchdog
}

public struct ThreadInfo: Codable {
    /// 主线程 CPU 时间占比（通过 thread_info THREAD_BASIC_INFO 获取）
    public let cpuUsage: Double
    /// 当前进程线程数
    public let threadCount: Int

    public init(cpuUsage: Double, threadCount: Int) {
        self.cpuUsage = cpuUsage
        self.threadCount = threadCount
    }
}

public struct CatonEvent: Codable {
    public let id: UUID
    public let type: CatonType
    /// 卡顿持续时长（毫秒）
    public let duration: Double
    /// 堆栈帧：Debug 下为符号化字符串，Release 下为原始地址
    public let stackTrace: [String]
    public let timestamp: Date
    public let threadInfo: ThreadInfo
    /// 当前页面类名（通过 PageTracker 获取）
    public let page: String?
    public let isAppInBackground: Bool

    public init(
        type: CatonType,
        duration: Double,
        stackTrace: [String],
        threadInfo: ThreadInfo,
        page: String?,
        isAppInBackground: Bool
    ) {
        self.id = UUID()
        self.type = type
        self.duration = duration
        self.stackTrace = stackTrace
        self.timestamp = Date()
        self.threadInfo = threadInfo
        self.page = page
        self.isAppInBackground = isAppInBackground
    }
}
