import Foundation

/// 与 JS 侧 `src/shared/events/common/navbar/events.ts` 对齐。
public enum NavbarEvents {
    public static let rightItemPress = "navbar.rightItemPress"

    public static let all: [String] = [
        rightItemPress,
    ]
}
