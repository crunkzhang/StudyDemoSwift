import Foundation

public final class APILogger: NetLoggable {
    #if DEBUG
    private let verbose = true
    #else
    private let verbose = false
    #endif

    public init() {}

    public func didStart(_ request: URLRequest) {
        let method = request.httpMethod ?? "UNKNOWN"
        let url = request.url?.absoluteString ?? "<nil>"
        print("[WeChatNet] → \(method) \(url)")
        if verbose, let body = request.httpBody, let str = String(data: body, encoding: .utf8) {
            print("[WeChatNet]   body: \(str)")
        }
    }

    public func didSucceed(_ request: URLRequest, response: HTTPURLResponse, data: Data) {
        let method = request.httpMethod ?? "UNKNOWN"
        let url = request.url?.absoluteString ?? "<nil>"
        print("[WeChatNet] ← \(method) \(url) [\(response.statusCode)] \(data.count)B")
        if verbose, let str = String(data: data, encoding: .utf8) {
            print("[WeChatNet]   resp: \(str)")
        }
    }

    public func didFail(_ request: URLRequest, error: Error) {
        let method = request.httpMethod ?? "UNKNOWN"
        let url = request.url?.absoluteString ?? "<nil>"
        print("[WeChatNet] ✕ \(method) \(url) error=\(error)")
    }

    public func didRetry(_ request: URLRequest, attempt: Int, error: Error) {
        let method = request.httpMethod ?? "UNKNOWN"
        let url = request.url?.absoluteString ?? "<nil>"
        print("[WeChatNet] ↻ retry #\(attempt) \(method) \(url) error=\(error)")
    }

    public func didCancel(_ request: URLRequest) {
        let url = request.url?.absoluteString ?? "<nil>"
        print("[WeChatNet] ✕ CANCELLED \(url)")
    }
}
