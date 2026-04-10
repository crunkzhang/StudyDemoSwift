import Foundation

public final class AuthInterceptor: NetInterceptable {
    private let tokenProvider: () -> String?
    private let headerField: String
    private let valueTransformer: (String) -> String

    public init(
        headerField: String = "Authorization",
        tokenProvider: @escaping () -> String?,
        valueTransformer: @escaping (String) -> String = { "Bearer \($0)" }
    ) {
        self.headerField = headerField
        self.tokenProvider = tokenProvider
        self.valueTransformer = valueTransformer
    }

    public func adapt(_ request: URLRequest, requiresAuth: Bool) async throws -> URLRequest {
        guard requiresAuth, let token = tokenProvider(), !token.isEmpty else {
            return request
        }

        var request = request
        request.setValue(valueTransformer(token), forHTTPHeaderField: headerField)
        return request
    }
}
