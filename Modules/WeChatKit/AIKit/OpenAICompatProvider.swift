import Foundation

/// 通用 OpenAI 兼容 provider:适配 DeepSeek / 通义千问(DashScope)/ 智谱 GLM 等。
/// 三家的 /chat/completions 请求与响应结构一致,仅 baseURL / model / key 不同。
public final class OpenAICompatProvider: AIProvider {
    private let baseURL: URL
    private let apiKey: String
    private let model: String
    private let jsonMode: Bool
    private let session: URLSession

    public init(baseURL: URL, apiKey: String, model: String,
                jsonMode: Bool = true, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.jsonMode = jsonMode
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

        var body: [String: Any] = [
            "model": model,
            "max_tokens": request.maxTokens,
            "temperature": request.temperature,
            "messages": messages
        ]
        if jsonMode { body["response_format"] = ["type": "json_object"] }
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
