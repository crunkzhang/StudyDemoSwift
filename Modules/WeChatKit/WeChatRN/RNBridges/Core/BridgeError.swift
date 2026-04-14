import Foundation

/// 与 JS 侧 `src/shared/bridges/core/bridgeError.ts` 对齐。
public enum BridgeError: String {
    case invalidParams = "INVALID_PARAMS"
    case cancelled = "CANCELLED"
    case permissionDenied = "PERMISSION_DENIED"
    case notAvailable = "NOT_AVAILABLE"
    case internalError = "INTERNAL"
}
