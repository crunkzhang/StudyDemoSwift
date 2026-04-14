import Foundation

/// 将 NSDictionary 派生 payload 解码成 Decodable。
enum BridgeDecode {
    static func decode<T: Decodable>(_ type: T.Type, from params: [String: Any]) -> T? {
        guard JSONSerialization.isValidJSONObject(params),
              let data = try? JSONSerialization.data(withJSONObject: params),
              let value = try? JSONDecoder().decode(type, from: data) else {
            return nil
        }
        return value
    }
}
