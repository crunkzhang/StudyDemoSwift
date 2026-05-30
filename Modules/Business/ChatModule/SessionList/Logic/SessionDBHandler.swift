import Foundation
import WCIMSDK

/// 封装 SessionDB 读取 + SessionModel → SessionCellModel 转换
final class SessionDBHandler {
    private let db: SessionDB

    init(db: SessionDB) {
        self.db = db
    }

    func fetchAll() -> [SessionCellModel] {
        db.fetchAll().map(Self.toCellModel)
    }

    func fetch(sessionIds: [String]) -> [SessionCellModel] {
        db.fetch(sessionIds: sessionIds).map(Self.toCellModel)
    }

    // MARK: - 转换

    static func toCellModel(_ m: SessionModel) -> SessionCellModel {
        SessionCellModel(
            sessionId: m.sessionId,
            contactName: m.contactName,
            avatarURL: m.avatarURL,
            lastMsgPreview: m.lastMsgPreview ?? "",
            formattedTime: formatTime(m.lastTimestamp),
            unreadCount: m.unreadCount,
            isPinned: m.isPinned,
            lastTimestamp: m.lastTimestamp
        )
    }

    private static let hmFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let mdFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M月d日"
        return f
    }()

    private static func formatTime(_ ts: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        let cal = Calendar.current
        if cal.isDateInToday(date) { return hmFormatter.string(from: date) }
        if cal.isDateInYesterday(date) { return "昨天" }
        return mdFormatter.string(from: date)
    }
}
