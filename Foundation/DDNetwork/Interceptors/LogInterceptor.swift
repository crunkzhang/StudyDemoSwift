import Foundation

public final class LogInterceptor: NetInterceptable {
    private let logger: (String) -> Void

    public init(logger: @escaping (String) -> Void = { print($0) }) {
        self.logger = logger
    }

    public func adapt(_ request: URLRequest, requiresAuth: Bool) async throws -> URLRequest {
        let method = request.httpMethod ?? "UNKNOWN"
        let url = request.url?.absoluteString ?? "<nil>"
        logger("[NetAPI] \(method) \(url)")
        return request
    }

    public func retry(_ request: URLRequest, dueTo error: Error, attempt: Int) async -> RetryDecision {
        let method = request.httpMethod ?? "UNKNOWN"
        let url = request.url?.absoluteString ?? "<nil>"
        logger("[NetAPI] retry-check attempt=\(attempt) \(method) \(url) error=\(error)")
        return .doNotRetry
    }
}
