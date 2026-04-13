import Foundation

/// 业务域归属。Endpoint 声明 `service` 后，网络层按当前 App 环境解析出对应 baseURL。
public enum APIService: String {
    case common
    case user
    case discover
    /// dog.ceo 占位服务，仅用于当前示例
    case petMock

    public func host(for env: APIEnv) -> URL {
        switch self {
        case .common:
            switch env {
            case .dev:     return URL(string: "https://dev-api.example.com")!
            case .preview: return URL(string: "https://preview-api.example.com")!
            case .prod:    return URL(string: "https://api.example.com")!
            }
        case .user:
            switch env {
            case .dev:     return URL(string: "https://user-dev.example.com")!
            case .preview: return URL(string: "https://user-preview.example.com")!
            case .prod:    return URL(string: "https://user.example.com")!
            }
        case .discover:
            switch env {
            case .dev:     return URL(string: "https://discover-dev.example.com")!
            case .preview: return URL(string: "https://discover-preview.example.com")!
            case .prod:    return URL(string: "https://discover.example.com")!
            }
        case .petMock:
            return URL(string: "https://dog.ceo")!
        }
    }
}
