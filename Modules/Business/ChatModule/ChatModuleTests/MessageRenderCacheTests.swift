import XCTest
@testable import ChatModule

final class MessageRenderCacheTests: XCTestCase {
    var cache: MessageRenderCache!

    override func setUp() {
        super.setUp()
        cache = MessageRenderCache()
    }

    func test_emptyCache_returnsNil() {
        XCTAssertNil(cache.height(for: "k1"))
        XCTAssertNil(cache.attributedText(for: "k1"))
    }

    func test_storeAndRetrieve_height() {
        cache.cache(height: 42, attributedText: nil, for: "k1")
        XCTAssertEqual(cache.height(for: "k1"), 42)
    }

    func test_storeAndRetrieve_attributedText() {
        let attr = NSAttributedString(string: "hello")
        cache.cache(height: 30, attributedText: attr, for: "k1")
        XCTAssertEqual(cache.attributedText(for: "k1"), attr)
    }

    func test_invalidate_removesEntry() {
        cache.cache(height: 42, attributedText: nil, for: "k1")
        cache.invalidate(["k1"])
        XCTAssertNil(cache.height(for: "k1"))
    }
}
