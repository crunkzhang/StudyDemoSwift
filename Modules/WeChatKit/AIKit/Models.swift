import Foundation

public enum AIRole: String, Codable {
    case user
    case assistant
}

public struct AIMessage: Equatable {
    public let role: AIRole
    public let content: String
    public init(role: AIRole, content: String) {
        self.role = role
        self.content = content
    }
}

public struct AIRequest {
    public var system: String
    public var messages: [AIMessage]
    public var maxTokens: Int
    public var temperature: Double
    public init(system: String, messages: [AIMessage], maxTokens: Int = 256, temperature: Double = 0.2) {
        self.system = system
        self.messages = messages
        self.maxTokens = maxTokens
        self.temperature = temperature
    }
}

public struct AIResponse: Equatable {
    public let text: String
    public init(text: String) { self.text = text }
}

public enum AIError: Error, Equatable {
    case network(String)      // 用 String 便于 Equatable / 测试
    case rateLimited
    case decoding
    case provider(message: String)
}
