import Foundation
import DDNetwork

/// 默认 HostResolver：按 (APIService, AppEnvironment.current) 解析 baseURL。
/// 未知 service 字符串兜底走 `.common`。
public struct DefaultHostResolver: HostResolving {
    public init() {}

    public func baseURL(for service: String) -> URL {
        guard let svc = APIService(rawValue: service) else {
            fatalError("Unknown APIService: \"\(service)\" — RN NetDomain 与 iOS APIService 两端枚举不同步")
        }
        return svc.host(for: AppEnvironment.current)
    }
}
