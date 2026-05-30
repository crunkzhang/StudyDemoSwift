import UIKit

/// 缓存消息的高度和富文本预排版。详情页 DBHandler fetchPage 后台预算 →
/// VC heightForRow 直接 O(1) 读缓存,主线程零计算。
public final class MessageRenderCache {

    private struct Entry {
        let height: CGFloat
        let attributedText: NSAttributedString?
    }

    private var storage: [String: Entry] = [:]
    private let lock = NSLock()

    public init() {}

    public func height(for key: String) -> CGFloat? {
        lock.lock(); defer { lock.unlock() }
        return storage[key]?.height
    }

    public func attributedText(for key: String) -> NSAttributedString? {
        lock.lock(); defer { lock.unlock() }
        return storage[key]?.attributedText
    }

    public func cache(height: CGFloat, attributedText: NSAttributedString?, for key: String) {
        lock.lock(); defer { lock.unlock() }
        storage[key] = Entry(height: height, attributedText: attributedText)
    }

    public func invalidate(_ keys: [String]) {
        lock.lock(); defer { lock.unlock() }
        for k in keys { storage.removeValue(forKey: k) }
    }
}
