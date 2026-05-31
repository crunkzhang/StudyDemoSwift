import Foundation

/// 灰度命中判定。
/// 相比"unicodeScalars 求和"的弱哈希,这里用 **FNV-1a(deviceId + pageId)**:
/// - 分布均匀(避免偏斜导致灰度比例失真)
/// - **按页独立**:同一设备在不同页面的灰度桶相互无关,而非"要么全中要么全不中"
enum Grayscale {
    static func hit(_ entry: PageEntry, deviceId: String) -> Bool {
        guard let g = entry.grayscale else { return true }            // 无灰度 = 全量
        if g.whitelist.contains(deviceId) { return true }             // 白名单直通
        let pct = max(0, min(100, g.percentage))
        if pct >= 100 { return true }
        if pct <= 0 { return false }
        let bucket = fnv1a("\(deviceId):\(entry.id)") % 100           // 0..99
        return bucket < UInt64(pct)
    }

    /// FNV-1a 64-bit:稳定、跨进程一致、分布良好。
    static func fnv1a(_ s: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in s.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}
