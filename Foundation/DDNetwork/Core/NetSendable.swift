import Foundation

public protocol NetSendable {
    func send<E: NetEndpoint>(_ endpoint: E) async throws -> E.Response
}

public enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

public enum NetError: Error {
    case invalidURL
    case invalidResponse
    case transport(Error)
    case server(statusCode: Int, data: Data)
    case decoding(Error)
    case businessError(code: Int, message: String)
}

extension NetError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .transport(let error):
            return "Transport error: \(error.localizedDescription)"
        case .server(let code, _):
            return "Server error: \(code)"
        case .decoding(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .businessError(_, let message):
            return message
        }
    }
}
