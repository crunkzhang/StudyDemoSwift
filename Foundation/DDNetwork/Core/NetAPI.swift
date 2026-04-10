import Foundation

public final class NetAPI: NetSendable {
    private let config: NetConfig
    private let session: URLSession
    private let reqBuilder: ReqBuilder
    private let respDecoder: RespDecoder
    private let interceptors: [NetInterceptable]
    private let logger: NetLoggable?

    public init(
        config: NetConfig,
        session: URLSession = .shared,
        interceptors: [NetInterceptable] = [],
        logger: NetLoggable? = nil
    ) {
        self.config = config
        self.session = session
        self.reqBuilder = ReqBuilder(config: config)
        self.respDecoder = RespDecoder(decoder: config.decoder)
        self.interceptors = interceptors
        self.logger = logger
    }

    public func send<E: NetEndpoint>(_ endpoint: E) async throws -> E.Response {
        try Task.checkCancellation()

        var request = try reqBuilder.build(endpoint)

        for interceptor in interceptors {
            request = try await interceptor.adapt(request, requiresAuth: endpoint.requiresAuth)
        }

        logger?.didStart(request)
        return try await execute(request, responseType: E.Response.self, attempt: 0)
    }

    private func execute<T: Decodable>(
        _ request: URLRequest,
        responseType: T.Type,
        attempt: Int
    ) async throws -> T {
        try Task.checkCancellation()

        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                let error = NetError.invalidResponse
                logger?.didFail(request, error: error)
                throw error
            }

            // 响应拦截链
            var processedData = data
            for interceptor in interceptors {
                processedData = try await interceptor.didReceive(httpResponse, data: processedData, for: request)
            }

            logger?.didSucceed(request, response: httpResponse, data: processedData)
            return try respDecoder.decode(responseType, from: processedData, response: response)
        } catch is CancellationError {
            logger?.didCancel(request)
            throw CancellationError()
        } catch {
            try Task.checkCancellation()

            for interceptor in interceptors {
                let decision = await interceptor.retry(request, dueTo: error, attempt: attempt)
                if decision == .retry && attempt < config.maxRetryCount {
                    logger?.didRetry(request, attempt: attempt + 1, error: error)
                    return try await execute(request, responseType: responseType, attempt: attempt + 1)
                }
            }

            if let netError = error as? NetError {
                logger?.didFail(request, error: netError)
                throw netError
            }

            let transportError = NetError.transport(error)
            logger?.didFail(request, error: transportError)
            throw transportError
        }
    }
}
