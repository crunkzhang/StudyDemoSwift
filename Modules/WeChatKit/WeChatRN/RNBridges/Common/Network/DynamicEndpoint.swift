import Foundation
import WeChatNetAPI

/// 由 RN 透传参数动态构造的 Endpoint，DataType=JSONValue，响应直接透出给 JS。
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
