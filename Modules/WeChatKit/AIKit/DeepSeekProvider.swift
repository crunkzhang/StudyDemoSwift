import Foundation

/// DeepSeek(OpenAI 兼容)provider。云端直连,DEBUG/RELEASE 均可用,无需本地代理。
/// 与 ClaudeProvider 的差异:system 进 messages、Bearer 鉴权、/chat/completions、choices 解析。
public final class DeepSeekProvider: AIProvider {
    private let baseURL: URL
    private let apiKey: String
    private let model: String
    private let session: URLSession

    public init(baseURL: URL = URL(string: "https://api.deepseek.com")!,
                apiKey: String,
                model: String = "deepseek-chat",
                session: URLSession = .shared) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    // MARK: - 可测纯函数

    func makeURLRequest(_ request: AIRequest) throws -> URLRequest {
        var urlReq = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        urlReq.httpMethod = "POST"
        urlReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlReq.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        var messages: [[String: Any]] = [["role": "system", "content": request.system]]
        messages += request.messages.map { ["role": $0.role.rawValue, "content": $0.content] }

        let body: [String: Any] = [
            "model": model,
            "max_tokens": request.maxTokens,
            "temperature": request.temperature,
            "messages": messages,
            // 我们的 prompt 均要求只输出 JSON,开启 JSON 模式提升可靠性
            "response_format": ["type": "json_object"]
        ]
        urlReq.httpBody = try JSONSerialization.data(withJSONObject: body)
        return urlReq
    }

    func parse(_ data: Data) throws -> AIResponse {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = obj["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.decoding
        }
        return AIResponse(text: content)
    }

    // MARK: - AIProvider

    public func complete(_ request: AIRequest) async throws -> AIResponse {
        let urlReq = try makeURLRequest(request)
        do {
            let (data, resp) = try await session.data(for: urlReq)
            if let http = resp as? HTTPURLResponse {
                if http.statusCode == 429 { throw AIError.rateLimited }
                guard (200..<300).contains(http.statusCode) else {
                    let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
                    throw AIError.provider(message: msg)
                }
            }
            return try parse(data)
        } catch let e as AIError {
            throw e
        } catch {
            throw AIError.network(error.localizedDescription)
        }
    }
}
