import Foundation

public enum RetryDecision {
    case doNotRetry
    case retry
}

public protocol NetInterceptable {
    func adapt(_ request: URLRequest, requiresAuth: Bool) async throws -> URLRequest
    func retry(_ request: URLRequest, dueTo error: Error, attempt: Int) async -> RetryDecision
    func didReceive(_ response: HTTPURLResponse, data: Data, for request: URLRequest) async throws -> Data
}

public extension NetInterceptable {
    func adapt(_ request: URLRequest, requiresAuth: Bool) async throws -> URLRequest {
        request
    }

    func retry(_ request: URLRequest, dueTo error: Error, attempt: Int) async -> RetryDecision {
        .doNotRetry
    }

    func didReceive(_ response: HTTPURLResponse, data: Data, for request: URLRequest) async throws -> Data {
        data
    }
}
