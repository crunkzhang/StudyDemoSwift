import Foundation

/// 宽松的 JSON 值:容纳 props 与 data(string/number/bool/null/object/array)。
/// 关键作用:遇到未知字段/类型不报错(向前兼容);支持嵌套以做数据绑定。
public indirect enum DSLValue: Decodable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case object([String: DSLValue])
    case array([DSLValue])
    case null

    public init(from decoder: Decoder) throws {
        // 1. 对象
        if let keyed = try? decoder.container(keyedBy: AnyKey.self) {
            var dict: [String: DSLValue] = [:]
            for key in keyed.allKeys {
                dict[key.stringValue] = try? keyed.decode(DSLValue.self, forKey: key)
            }
            self = .object(dict)
            return
        }
        // 2. 数组
        if var unkeyed = try? decoder.unkeyedContainer() {
            var arr: [DSLValue] = []
            while !unkeyed.isAtEnd {
                if let v = try? unkeyed.decode(DSLValue.self) { arr.append(v) }
                else { _ = try? unkeyed.decode(EmptyDecodable.self) }
            }
            self = .array(arr)
            return
        }
        // 3. 标量
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let i = try? c.decode(Int.self) { self = .int(i) }
        else if let d = try? c.decode(Double.self) { self = .double(d) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else { self = .null }
    }

    // MARK: - 取值
    public var stringValue: String? {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        case .bool(let b): return b ? "true" : "false"
        default: return nil
        }
    }
    public var intValue: Int? {
        switch self {
        case .int(let i): return i
        case .double(let d): return Int(d)
        default: return nil
        }
    }
    public var boolValue: Bool? {
        if case .bool(let b) = self { return b }
        return nil
    }
    public var objectValue: [String: DSLValue]? {
        if case .object(let o) = self { return o }
        return nil
    }
    public var arrayValue: [DSLValue]? {
        if case .array(let a) = self { return a }
        return nil
    }

    /// 按点路径取值:value(at: "user.name")
    public func value(at path: String) -> DSLValue? {
        var current: DSLValue? = self
        for seg in path.split(separator: ".") {
            guard case .object(let dict)? = current else { return nil }
            current = dict[String(seg)]
        }
        return current
    }

    struct AnyKey: CodingKey {
        let stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { return nil }
    }
    private struct EmptyDecodable: Decodable {}
}
