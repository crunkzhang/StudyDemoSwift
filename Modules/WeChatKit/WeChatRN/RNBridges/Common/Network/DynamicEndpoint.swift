import Foundation
import WeChatNetAPI

/// 标准 APIResp<T> 外壳的 Endpoint，DataType=JSONValue。业务域（envelope=true）使用。
struct DynamicEndpoint: APIEndpoint {
    typealias DataType = JSONValue

    let service: String
    let path: String
    let method: HTTPMethod
    let headers: [String: String]
    let queryItems: [URLQueryItem]
    let body: Encodable?
    let requiresAuth: Bool
}

/// 无外壳 Endpoint，Response=JSONValue。第三方/mock 域（envelope=false）使用，走 sendRaw 原样透传。
struct RawDynamicEndpoint: NetEndpoint {
    typealias Response = JSONValue

    let service: String
    let path: String
    let method: HTTPMethod
    let headers: [String: String]
    let queryItems: [URLQueryItem]
    let body: Encodable?
    let requiresAuth: Bool
}
