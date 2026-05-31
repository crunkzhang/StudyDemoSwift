import Foundation

public protocol AIProvider {
    func complete(_ request: AIRequest) async throws -> AIResponse
    /// 流式输出:逐段 yield 增量文本(delta)。默认实现退化为一次性返回。
    func completeStream(_ request: AIRequest) -> AsyncThrowingStream<String, Error>
}

public extension AIProvider {
    func completeStream(_ request: AIRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let r = try await complete(request)
                    continuation.yield(r.text)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
