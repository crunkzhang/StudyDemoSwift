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
            avatarInitial: String(m.contactName.prefix(1)),
            avatarColor: pickColor(for: m.sessionId),
            lastMsgPreview: m.lastMsgPreview ?? "",
            formattedTime: formatTime(m.lastTimestamp),
            unreadCount: m.unreadCount,
            isPinned: m.isPinned,
            lastTimestamp: m.lastTimestamp,
            draft: m.draft
        )
    }

    /// 兜底色块色板(微信常用绿/蓝/橙/红/紫等),按 sessionId 稳定取色
    private static let avatarPalette: [UInt32] = [
        0x07C160, 0x576B95, 0xFA9D3B, 0xE75A5A, 0x8B72BE,
        0x2AAE67, 0xCC6633, 0x3399CC, 0xE6567A, 0x44BB77,
    ]

    private static func pickColor(for sessionId: String) -> UInt32 {
        let sum = sessionId.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return avatarPalette[abs(sum) % avatarPalette.count]
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
