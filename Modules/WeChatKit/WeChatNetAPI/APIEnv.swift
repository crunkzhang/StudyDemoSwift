import Foundation

public enum APIEnv {
    case dev
    case staging
    case prod

    var baseURL: URL {
        switch self {
        case .dev:     return URL(string: "https://dev-api.example.com")!
        case .staging: return URL(string: "https://staging-api.example.com")!
        case .prod:    return URL(string: "https://api.example.com")!
        }
    }
}
