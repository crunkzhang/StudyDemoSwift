import Foundation

/// 消息内容 — Codable enum,后续扩展图片/语音只加 case,序列化格式向前兼容。
/// 持久化时通过 jsonString 写入 MessageModel.contentJSON,解析时通过 init(jsonString:) 还原。
public enum MessageContent: Codable, Equatable {
    case text(String)
    /// DSL 卡片消息:payload 为卡片 schema 的 JSON 字符串(订单卡/链接卡等)
    case card(String)
    // 未来:case image(url:String, width:Int, height:Int)
    //       case voice(url:String, duration:Int)

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey { case type, text, card }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let s):
            try c.encode("text", forKey: .type)
            try c.encode(s, forKey: .text)
        case .card(let json):
            try c.encode("card", forKey: .type)
            try c.encode(json, forKey: .card)
        }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(String.self, forKey: .type)
        switch type {
        case "text":
            let s = try c.decodeIfPresent(String.self, forKey: .text) ?? ""
            self = .text(s)
        case "card":
            let json = try c.decodeIfPresent(String.self, forKey: .card) ?? "{}"
            self = .card(json)
        default:
            // 旧客户端遇到未知 type 兜底为空文本(向前兼容,不崩)
            self = .text("")
        }
    }

    // MARK: - 持久化 helper

    public var jsonString: String {
        guard let data = try? JSONEncoder().encode(self),
              let s = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return s
    }

    public init(jsonString: String) {
        if let data = jsonString.data(using: .utf8),
           let c = try? JSONDecoder().decode(MessageContent.self, from: data) {
            self = c
            return
        }
        // 老格式兼容:{"text": "..."} 直接当作 text 解析
        if let data = jsonString.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = dict["text"] as? String {
            self = .text(text)
            return
        }
        self = .text("")
    }

    // MARK: - UI 展示

    public var displayText: String {
        switch self {
        case .text(let s): return s
        case .card: return "[卡片]"
        }
    }

    /// 卡片 payload(仅 .card 有值)
    public var cardJSON: String? {
        if case .card(let json) = self { return json }
        return nil
    }
}
