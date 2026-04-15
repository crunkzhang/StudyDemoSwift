import Foundation

/// 桥接层与原生网络层之间透传任意 JSON 的中间值。
/// 同时实现 Decodable/Encodable，可作为 DynamicEndpoint.body 使用。
enum JSONValue: Codable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Double.self) { self = .number(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([JSONValue].self) { self = .array(v); return }
        if let v = try? c.decode([String: JSONValue].self) { self = .object(v); return }
        throw DecodingError.typeMismatch(
            JSONValue.self,
            .init(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value")
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .object(let v): try c.encode(v)
        }
    }

    /// 转为可返回给 RN 的 Any（NSDictionary/NSArray/NSNumber/NSString/NSNull）。
    var anyValue: Any {
        switch self {
        case .null: return NSNull()
        case .bool(let v): return v
        case .number(let v):
            if v.rounded() == v, v >= Double(Int64.min), v <= Double(Int64.max) {
                return Int64(v)
            }
            return v
        case .string(let v): return v
        case .array(let v): return v.map { $0.anyValue }
        case .object(let v): return v.mapValues { $0.anyValue }
        }
    }

    /// 从 [String: Any]/[Any] 等构造。未知类型返回 nil。
    static func from(_ any: Any?) -> JSONValue {
        guard let any = any else { return .null }
        if any is NSNull { return .null }
        if let v = any as? Bool, (any as? NSNumber)?.isBool == true { return .bool(v) }
        if let v = any as? NSNumber {
            if v.isBool { return .bool(v.boolValue) }
            return .number(v.doubleValue)
        }
        if let v = any as? String { return .string(v) }
        if let v = any as? [Any] { return .array(v.map(JSONValue.from)) }
        if let v = any as? [String: Any] { return .object(v.mapValues(JSONValue.from)) }
        return .null
    }
}

private extension NSNumber {
    var isBool: Bool {
        CFGetTypeID(self) == CFBooleanGetTypeID()
    }
}
