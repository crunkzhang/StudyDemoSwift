import Foundation
@_exported import DDNetwork

public protocol APIEndpoint: NetEndpoint where Response == APIResp<DataType> {
    associatedtype DataType: Decodable
}

public extension APIEndpoint {
    var method: HTTPMethod { .get }
    var requiresAuth: Bool { true }
}
