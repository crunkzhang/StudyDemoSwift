import Foundation

public final class ClaudeProvider: AIProvider {
    private let baseURL: URL
    private let apiKey: String?
    private let model: String
    private let session: URLSession

    public init(baseURL: URL, apiKey: String?, model: String, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    // MARK: - 可测纯函数

    func makeURLRequest(_ request: AIRequest) throws -> URLRequest {
        var urlReq = URLRequest(url: baseURL.appendingPathComponent("v1/messages"))
        urlReq.httpMethod = "POST"
        urlReq.setValue("application/json", forHTTPHeaderField: "content-type")
        urlReq.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        if let key = apiKey { urlReq.setValue(key, forHTTPHeaderField: "x-api-key") }
        let body: [String: Any] = [
            "model": model,
            "max_tokens": request.maxTokens,
            "temperature": request.temperature,
            "system": request.system,
            "messages": request.messages.map { ["role": $0.role.rawValue, "content": $0.content] }
        ]
        urlReq.httpBody = try JSONSerialization.data(withJSONObject: body)
        return urlReq
    }

    func parse(_ data: Data) throws -> AIResponse {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = obj["content"] as? [[String: Any]] else {
            throw AIError.decoding
        }
        let text = content.compactMap { $0["text"] as? String }.joined()
        return AIResponse(text: text)
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
