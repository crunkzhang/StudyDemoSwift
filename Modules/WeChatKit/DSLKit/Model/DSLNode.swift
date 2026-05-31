import Foundation

/// 一页的 schema 根。
public struct DSLPage: Decodable {
    public let page: String
    public let version: String
    /// 渲染本页所需的最低客户端能力版本;超过 DSLKit.capabilityVersion 则回退兜底。
    public let minClient: Int?
    public let background: String?
    /// 导航标题(可选)
    public let title: String?
    /// 渲染方式:"collection"(楼层型)/ 缺省 / "list"(列表型,默认)
    public let layout: String?
    /// 页面内嵌数据源,供 {{path}} 绑定
    public let data: DSLValue?
    public let sections: [DSLNode]
}

/// 通用节点:已知字段(type/children)单独取,其余全部进 props(向前兼容)。
public struct DSLNode {
    public let type: String
    public let children: [DSLNode]?
    public let props: [String: DSLValue]

    public init(type: String, children: [DSLNode]? = nil, props: [String: DSLValue] = [:]) {
        self.type = type
        self.children = children
        self.props = props
    }

    // MARK: - 便捷取值
    public func string(_ key: String) -> String? { props[key]?.stringValue }
    public func int(_ key: String) -> Int? { props[key]?.intValue }
    public func bool(_ key: String) -> Bool? { props[key]?.boolValue }
    public var action: String? { props["action"]?.stringValue }
}

extension DSLNode: Decodable {
    private struct AnyKey: CodingKey {
        let stringValue: String
        init?(stringValue: String) { self.stringValue = stringValue }
        var intValue: Int? { nil }
        init?(intValue: Int) { return nil }
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: AnyKey.self)
        var type = ""
        var children: [DSLNode]? = nil
        var props: [String: DSLValue] = [:]
        for key in c.allKeys {
            switch key.stringValue {
            case "type":
                type = (try? c.decode(String.self, forKey: key)) ?? ""
            case "children":
                children = try? c.decode([DSLNode].self, forKey: key)
            default:
                // 未知字段也照收;解码失败的字段直接忽略,不影响整体
                props[key.stringValue] = try? c.decode(DSLValue.self, forKey: key)
            }
        }
        self.type = type
        self.children = children
        self.props = props
    }
}
