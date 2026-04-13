import Foundation

public protocol NetEndpoint {
    associatedtype Response: Decodable

    /// 服务归属标识。由上层业务网络库定义具体枚举，底层仅接受 String 以保持解耦。
    /// 默认 "" 表示公共服务（由 HostResolver 兜底处理）。
    var service: String { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String] { get }
    var queryItems: [URLQueryItem] { get }
    var body: Encodable? { get }
    var requiresAuth: Bool { get }
}

public extension NetEndpoint {
    var service: String { "" }
    var headers: [String: String] { [:] }
    var queryItems: [URLQueryItem] { [] }
    var body: Encodable? { nil }
    var requiresAuth: Bool { true }
}

public protocol HostResolving {
    /// 根据服务标识解析 baseURL。未知 service 由实现方决定兜底。
    func baseURL(for service: String) -> URL
}
