import Foundation

/// 数据上下文:页面内嵌 data + 宿主注入的运行时数据,合并后供 {{}} 绑定。
public struct DSLContext {
    private var root: [String: DSLValue]

    public init(pageData: DSLValue? = nil, injected: [String: DSLValue] = [:]) {
        var dict = pageData?.objectValue ?? [:]
        // 宿主注入覆盖页面内嵌
        for (k, v) in injected { dict[k] = v }
        self.root = dict
    }

    public func value(at path: String) -> DSLValue? {
        DSLValue.object(root).value(at: path)
    }
}

/// 模板解析:把字符串里的 {{path}} 替换为 context 中对应的值。
/// 无匹配则替换为空串;无 {{}} 的字符串原样返回(零开销)。
public enum DSLTemplate {
    public static func resolve(_ text: String?, _ context: DSLContext) -> String? {
        guard let text, text.contains("{{") else { return text }
        var result = ""
        var rest = Substring(text)
        while let open = rest.range(of: "{{") {
            result += rest[..<open.lowerBound]
            let afterOpen = rest[open.upperBound...]
            guard let close = afterOpen.range(of: "}}") else {
                result += "{{"
                rest = afterOpen
                continue
            }
            let path = afterOpen[..<close.lowerBound].trimmingCharacters(in: .whitespaces)
            result += context.value(at: path)?.stringValue ?? ""
            rest = afterOpen[close.upperBound...]
        }
        result += rest
        return result
    }
}
