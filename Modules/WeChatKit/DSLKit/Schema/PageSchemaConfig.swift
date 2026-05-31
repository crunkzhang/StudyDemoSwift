import Foundation

/// DSLKit 运行配置(可在 AppDelegate 注入,集中管理超时/能力版本/安全策略)。
public struct PageSchemaConfig {
    /// 网络请求超时(秒)
    public var requestTimeout: TimeInterval = 10
    /// 客户端能力版本:schema 的 minClient 超过此值视为不支持,回退兜底
    public var capabilityVersion: Int = DSLKit.capabilityVersion
    /// action 路由白名单 scheme;非白名单 action 被拒绝(防被污染的 schema 跳外链)
    public var allowedSchemes: Set<String> = ["wechat"]

    public init() {}
}

/// 页面 schema 来源(用于可观测:命中下发 / 兜底 / 无)。
public enum PageSource: Equatable {
    case remoteCache   // OSS 下发并缓存的版本
    case builtin       // app 内置兜底
    case none          // 啥都没有
}

/// 可观测回调:接埋点/监控系统。所有方法默认空实现,按需重写。
public protocol PageSchemaObserver: AnyObject {
    func schema(didUpdate pageId: String, version: String)
    func schema(refreshFailed error: Error)
    func schema(validationFailed pageId: String, reason: String)
    func schema(fallbackUsed pageId: String, source: PageSource)
}

public extension PageSchemaObserver {
    func schema(didUpdate pageId: String, version: String) {}
    func schema(refreshFailed error: Error) {}
    func schema(validationFailed pageId: String, reason: String) {}
    func schema(fallbackUsed pageId: String, source: PageSource) {}
}
