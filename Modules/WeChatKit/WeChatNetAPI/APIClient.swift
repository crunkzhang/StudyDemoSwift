import Foundation

public final class APIClient {
    private let net: NetSendable

    public init(
        hostResolver: HostResolving = DefaultHostResolver(),
        tokenProvider: @escaping () -> String? = { nil }
    ) {
        let config = NetConfig(
            hostResolver: hostResolver,
            defaultHeaders: [
                "Accept": "application/json",
                "Content-Type": "application/json",
                "X-Platform": "iOS",
            ],
            commonQueryItems: [
                URLQueryItem(name: "lang", value: Locale.current.identifier),
            ]
        )

        self.net = NetAPI(
            config: config,
            interceptors: [
                AuthInterceptor(tokenProvider: tokenProvider),
            ],
            logger: APILogger()
        )
    }

    /// 业务发送：拆包 APIResp，校验 code，直接返回 T
    public func send<T: Decodable, E: NetEndpoint>(
        _ endpoint: E
    ) async throws -> T where E.Response == APIResp<T> {
        let resp = try await net.send(endpoint)
        guard resp.code == 0 else {
            throw NetError.businessError(code: resp.code, message: resp.message)
        }
        return resp.data
    }

    /// 原始发送，用于非标准响应格式
    public func sendRaw<E: NetEndpoint>(_ endpoint: E) async throws -> E.Response {
        try await net.send(endpoint)
    }
}
