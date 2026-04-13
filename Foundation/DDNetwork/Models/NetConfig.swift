import Foundation

public struct NetConfig {
    public let hostResolver: HostResolving
    public let defaultHeaders: [String: String]
    public let commonQueryItems: [URLQueryItem]
    public let timeoutInterval: TimeInterval
    public let maxRetryCount: Int
    public let encoder: JSONEncoder
    public let decoder: JSONDecoder

    public init(
        hostResolver: HostResolving,
        defaultHeaders: [String: String] = [:],
        commonQueryItems: [URLQueryItem] = [],
        timeoutInterval: TimeInterval = 30,
        maxRetryCount: Int = 3,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.hostResolver = hostResolver
        self.defaultHeaders = defaultHeaders
        self.commonQueryItems = commonQueryItems
        self.timeoutInterval = timeoutInterval
        self.maxRetryCount = maxRetryCount
        self.encoder = encoder
        self.decoder = decoder
    }
}
