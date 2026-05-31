import Foundation

/// 海龟汤等业务使用的 AI 厂商(均为 OpenAI 兼容)。
public enum AIVendor: String, CaseIterable {
    case deepseek
    case qwen
    case zhipu

    public var displayName: String {
        switch self {
        case .deepseek: return "DeepSeek"
        case .qwen:     return "通义千问"
        case .zhipu:    return "智谱 GLM"
        }
    }

    var baseURL: URL {
        switch self {
        case .deepseek: return URL(string: "https://api.deepseek.com")!
        case .qwen:     return URL(string: "https://dashscope.aliyuncs.com/compatible-mode/v1")!
        case .zhipu:    return URL(string: "https://open.bigmodel.cn/api/paas/v4")!
        }
    }

    var model: String {
        switch self {
        case .deepseek: return "deepseek-chat"
        case .qwen:     return "qwen-plus"
        case .zhipu:    return "glm-4-flash"
        }
    }
}

/// 其它(非业务多厂商)装配方式,保留兼容。
public enum AIProviderKind {
    case claudeDirect(apiKey: String)
    case claudeProxy(baseURL: URL)
    case mock(AIProvider)
}

public enum AIConfig {
    private static let selectedKey = "ai.selectedVendor"

    /// 当前选择的厂商(持久化在 UserDefaults,默认 DeepSeek)
    public static var current: AIVendor {
        get { AIVendor(rawValue: UserDefaults.standard.string(forKey: selectedKey) ?? "") ?? .deepseek }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: selectedKey) }
    }

    /// 按当前选择 + Keychain 里的 key 装配 AIClient。App 启动 / 切换后调用。
    public static func installSelected() {
        let vendor = current
        let key = KeychainAIKey.load(vendor.rawValue) ?? ""
        AIClient.shared.setProvider(
            OpenAICompatProvider(baseURL: vendor.baseURL, apiKey: key, model: vendor.model)
        )
    }

    /// 运行时切换厂商:持久化 + 重新装配。
    public static func select(_ vendor: AIVendor) {
        current = vendor
        installSelected()
    }

    /// 兼容旧的显式装配(claude / mock)。
    public static func install(_ kind: AIProviderKind) {
        let provider: AIProvider
        switch kind {
        case .claudeDirect(let key):
            provider = ClaudeProvider(baseURL: URL(string: "https://api.anthropic.com")!,
                                      apiKey: key, model: "claude-opus-4-8")
        case .claudeProxy(let baseURL):
            provider = ClaudeProvider(baseURL: baseURL, apiKey: nil, model: "claude-opus-4-8")
        case .mock(let p):
            provider = p
        }
        AIClient.shared.setProvider(provider)
    }
}
