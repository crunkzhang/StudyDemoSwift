import Foundation
import React
import WeChatNetAPI

@objc(NetBridge)
final class NetBridge: NSObject {

    @objc static func requiresMainQueueSetup() -> Bool { false }

    private static let client = APIClient()

    // requestId -> Task；用于支持 cancel。
    private let lock = NSLock()
    private var tasks: [String: Task<Void, Never>] = [:]

    /// 请求入口。params 结构与 JS 侧 HttpConfig 对齐：
    /// { method, domain, path, query?, body?, headers?, timeout?, requestId? }
    @objc func request(
        _ params: NSDictionary,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        guard
            let method = (params["method"] as? String)?.uppercased(),
            let httpMethod = HTTPMethod(rawValue: method),
            let domain = params["domain"] as? String,
            let path = params["path"] as? String
        else {
            reject(BridgeError.invalidParams.rawValue, "method/domain/path required", nil)
            return
        }

        let query = params["query"] as? [String: Any] ?? [:]
        let bodyAny = params["body"] as? [String: Any]
        let headers = params["headers"] as? [String: String] ?? [:]
        let requestId = params["requestId"] as? String

        let queryItems = query.map { URLQueryItem(name: $0.key, value: stringify($0.value)) }
        let body: Encodable? = bodyAny.map { JSONValue.from($0) }

        let service = APIService(rawValue: domain)
        let requiresAuth = (params["auth"] as? Bool)
            ?? service?.defaultRequiresAuth
            ?? true
        let raw = service.map { !$0.usesAPIRespEnvelope } ?? false

        let task = Task { [weak self] in
            defer {
                if let requestId = requestId { self?.removeTask(requestId) }
            }
            do {
                let value: JSONValue
                if raw {
                    let endpoint = RawDynamicEndpoint(
                        service: domain, path: path, method: httpMethod,
                        headers: headers, queryItems: queryItems,
                        body: body, requiresAuth: requiresAuth
                    )
                    value = try await Self.client.sendRaw(endpoint)
                } else {
                    let endpoint = DynamicEndpoint(
                        service: domain, path: path, method: httpMethod,
                        headers: headers, queryItems: queryItems,
                        body: body, requiresAuth: requiresAuth
                    )
                    value = try await Self.client.send(endpoint)
                }
                resolve(value.anyValue)
            } catch is CancellationError {
                reject(BridgeError.cancelled.rawValue, "Request cancelled", nil)
            } catch let NetError.businessError(code, message) {
                reject(BridgeError.businessCode(code), message, nil)
            } catch {
                reject(BridgeError.internalError.rawValue, error.localizedDescription, error)
            }
        }

        if let requestId = requestId {
            lock.lock(); tasks[requestId] = task; lock.unlock()
        }
    }

    @objc func cancel(_ requestId: String) {
        lock.lock()
        let task = tasks.removeValue(forKey: requestId)
        lock.unlock()
        task?.cancel()
    }

    private func removeTask(_ requestId: String) {
        lock.lock()
        tasks.removeValue(forKey: requestId)
        lock.unlock()
    }

    private func stringify(_ any: Any) -> String {
        if let s = any as? String { return s }
        if let n = any as? NSNumber { return n.stringValue }
        if let b = any as? Bool { return b ? "true" : "false" }
        return "\(any)"
    }
}
