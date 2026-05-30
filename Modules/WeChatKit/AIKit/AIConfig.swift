import Foundation

public enum AIProviderKind {
    case claudeDirect(apiKey: String)               // https://api.anthropic.com
    case claudeProxy(baseURL: URL)                  // 本地代理蹭 Max,无需 key
    case mock(AIProvider)
}

public enum AIConfig {
    public static let defaultModel = "claude-opus-4-8"

    /// App 启动时调用,按环境装配 AIClient.shared 的 provider。
    public static func install(_ kind: AIProviderKind) {
        let provider: AIProvider
        switch kind {
        case .claudeDirect(let key):
            provider = ClaudeProvider(baseURL: URL(string: "https://api.anthropic.com")!,
                                      apiKey: key, model: defaultModel)
        case .claudeProxy(let baseURL):
            provider = ClaudeProvider(baseURL: baseURL, apiKey: nil, model: defaultModel)
        case .mock(let p):
            provider = p
        }
        AIClient.shared.setProvider(provider)
    }
}
