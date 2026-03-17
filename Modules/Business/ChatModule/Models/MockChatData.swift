import Foundation

public struct MockChatData {
    public static let avatarColors: [UInt32] = [
        0x07C160, 0x576B95, 0xFA9D3B, 0xE75A5A, 0x8B72BE,
        0x2AAE67, 0xCC6633, 0x3399CC, 0xE6567A, 0x44BB77
    ]

    private static let names = [
        "张伟", "王芳", "李娜", "刘洋", "陈静",
        "杨帆", "赵磊", "黄丽", "周杰", "吴敏",
        "徐强", "孙艳", "马超", "朱婷", "胡军",
        "郭靖", "林黛", "何冰", "高远", "罗琳",
        "梁思", "宋雨", "唐风", "韩雪", "冯晨",
        "董明", "萧峰", "程瑶", "曹操", "袁术",
        "邓超", "许巍", "傅雷", "沈默", "曾国",
        "彭湃", "吕布", "苏轼", "卢俊", "蒋介",
        "蔡琴", "贾宝", "丁磊", "魏征", "薛涛",
        "叶问", "阎罗", "余华", "潘安", "杜甫",
    ]

    private static let messages = [
        "今晚一起吃饭吗？",
        "好的，收到",
        "明天开会记得带资料",
        "[图片]",
        "[语音] 0:15",
        "周末去爬山吧",
        "哈哈哈哈哈",
        "你在哪里？",
        "我到了，在门口等你",
        "这个项目什么时候截止？",
        "[文件] 需求文档v2.pdf",
        "晚安🌙",
        "早上好！",
        "帮我带杯咖啡",
        "会议改到下午3点了",
        "收到，马上处理",
        "[链接] 今日头条新闻",
        "生日快乐！🎂",
        "下班了吗？",
        "刚到家",
        "明天见",
        "好久不见，最近怎么样？",
        "在忙吗？",
        "等一下，马上来",
        "[红包] 恭喜发财",
        "谢谢！",
        "没问题",
        "我看看",
        "转账已收到",
        "周一再说吧",
    ]

    public static func generate() -> [ChatConversation] {
        let calendar = Calendar.current
        let now = Date()
        var conversations: [ChatConversation] = []

        for i in 0..<100 {
            let nameIdx = i % names.count
            let name = names[nameIdx]
            let initial = String(name.prefix(1))
            let color = avatarColors[i % avatarColors.count]
            let message = messages[i % messages.count]

            // Spread timestamps: first 10 today, next 10 yesterday, rest further back
            let timestamp: Date
            switch i {
            case 0..<10:
                timestamp = calendar.date(byAdding: .minute, value: -(i * 15), to: now)!
            case 10..<20:
                timestamp = calendar.date(byAdding: .hour, value: -(24 + i), to: now)!
            case 20..<40:
                timestamp = calendar.date(byAdding: .day, value: -(i / 5), to: now)!
            default:
                timestamp = calendar.date(byAdding: .day, value: -(i / 3), to: now)!
            }

            let unread = i < 5 ? (5 - i) : (i % 7 == 0 ? Int.random(in: 1...99) : 0)

            conversations.append(ChatConversation(
                id: "chat_\(i)",
                contactName: name,
                avatarInitial: initial,
                avatarColor: color,
                lastMessage: message,
                timestamp: timestamp,
                unreadCount: unread
            ))
        }

        return conversations
    }
}
