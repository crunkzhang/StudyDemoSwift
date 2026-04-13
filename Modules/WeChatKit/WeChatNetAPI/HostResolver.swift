import Foundation
import DDNetwork

/// 默认 HostResolver：按 (APIService, AppEnvironment.current) 解析 baseURL。
/// 未知 service 字符串兜底走 `.common`。
public struct DefaultHostResolver: HostResolving {
    public init() {}

    public func baseURL(for service: String) -> URL {
        let svc = APIService(rawValue: service) ?? .common
        return svc.host(for: AppEnvironment.current)
    }
}
