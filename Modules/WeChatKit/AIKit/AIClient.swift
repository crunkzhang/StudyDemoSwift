import Foundation

public final class AIClient {
    public static let shared = AIClient(provider: MockProvider { _ in
        .success(AIResponse(text: "{}"))   // 默认空 Mock,App 启动时由 AIConfig 替换
    })

    private var provider: AIProvider
    private let lock = NSLock()

    public init(provider: AIProvider) { self.provider = provider }

    public func setProvider(_ p: AIProvider) {
        lock.lock(); defer { lock.unlock() }
        provider = p
    }

    public func complete(_ request: AIRequest) async throws -> AIResponse {
        lock.lock(); let p = provider; lock.unlock()
        return try await p.complete(request)
    }
}
