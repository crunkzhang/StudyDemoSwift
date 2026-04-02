import Foundation

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
