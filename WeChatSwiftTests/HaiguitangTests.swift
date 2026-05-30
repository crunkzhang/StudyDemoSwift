import XCTest
import AIKit
@testable import GameModule

// 测试用:线程安全顺序取值(被多个海龟汤测试共用)
final class Box {
    private var items: [String]; private let lock = NSLock()
    init(_ items: [String]) { self.items = items }
    func next() -> String { lock.lock(); defer { lock.unlock() }
        return items.isEmpty ? "{}" : items.removeFirst() }
}

final class HaiguitangServiceTests: XCTestCase {
    // Task 6 起逐步追加
}
