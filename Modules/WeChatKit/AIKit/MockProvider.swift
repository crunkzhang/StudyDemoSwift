import Foundation

/// 预设响应,用于单测 / CI / 离线演示。零成本,不发网络。
public final class MockProvider: AIProvider {
    private let handler: (AIRequest) -> Result<AIResponse, AIError>

    public init(handler: @escaping (AIRequest) -> Result<AIResponse, AIError>) {
        self.handler = handler
    }

    public func complete(_ request: AIRequest) async throws -> AIResponse {
        switch handler(request) {
        case .success(let r): return r
        case .failure(let e): throw e
        }
    }
}
