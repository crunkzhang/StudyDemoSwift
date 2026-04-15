import Foundation

/// 与 JS 侧 `src/shared/bridges/core/bridgeError.ts` 对齐。
public enum BridgeError: String {
    case invalidParams = "INVALID_PARAMS"
    case cancelled = "CANCELLED"
    case permissionDenied = "PERMISSION_DENIED"
    case notAvailable = "NOT_AVAILABLE"
    case internalError = "INTERNAL"

    /// 业务错误 reject code 前缀。任何桥都可使用；来自哪个桥由 JS 调用点隐式区分。
    /// 必须与 JS 侧 bridgeError.ts 的 BUSINESS_PREFIX 保持一致。
    public static let businessPrefix = "BIZ_"

    /// 拼装业务错误 reject code
    public static func businessCode(_ code: Int) -> String {
        "\(businessPrefix)\(code)"
    }
}
