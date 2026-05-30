import Foundation

public protocol AIProvider {
    func complete(_ request: AIRequest) async throws -> AIResponse
}
