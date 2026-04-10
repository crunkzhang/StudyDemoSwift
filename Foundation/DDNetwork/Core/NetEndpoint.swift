import Foundation

public protocol NetEndpoint {
    associatedtype Response: Decodable

    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String] { get }
    var queryItems: [URLQueryItem] { get }
    var body: Encodable? { get }
    var requiresAuth: Bool { get }
}

public extension NetEndpoint {
    var headers: [String: String] { [:] }
    var queryItems: [URLQueryItem] { [] }
    var body: Encodable? { nil }
    var requiresAuth: Bool { true }
}
