import Foundation

struct ChatConversation {
    let id: String
    let contactName: String
    let avatarInitial: String
    let avatarColor: UInt32
    let lastMessage: String
    let timestamp: Date
    let unreadCount: Int

    var formattedTime: String {
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
