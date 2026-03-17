import Foundation

public struct ChatConversation {
    public let id: String
    public let contactName: String
    public let avatarInitial: String
    public let avatarColor: UInt32
    public let lastMessage: String
    public let timestamp: Date
    public let unreadCount: Int

    public init(id: String, contactName: String, avatarInitial: String, avatarColor: UInt32, lastMessage: String, timestamp: Date, unreadCount: Int) {
        self.id = id
        self.contactName = contactName
        self.avatarInitial = avatarInitial
        self.avatarColor = avatarColor
        self.lastMessage = lastMessage
        self.timestamp = timestamp
        self.unreadCount = unreadCount
    }

    public var formattedTime: String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(timestamp) {
            let fmt = DateFormatter()
            fmt.dateFormat = "HH:mm"
            return fmt.string(from: timestamp)
        }

        if calendar.isDateInYesterday(timestamp) {
            return "昨天"
        }

        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
        if timestamp > weekAgo {
            let weekdays = ["日", "一", "二", "三", "四", "五", "六"]
            let idx = calendar.component(.weekday, from: timestamp) - 1
            return "星期\(weekdays[idx])"
        }

        let fmt = DateFormatter()
        if calendar.component(.year, from: timestamp) == calendar.component(.year, from: now) {
            fmt.dateFormat = "M月d日"
        } else {
            fmt.dateFormat = "yyyy/M/d"
        }
        return fmt.string(from: timestamp)
    }
}
