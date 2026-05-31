import XCTest
@testable import DSLKit

final class PageSchemaTests: XCTestCase {

    private func entry(grayscaleJSON: String) throws -> PageEntry {
        let json = """
        { "id": "me", "version": "1.0",
          "url": "https://x/me.json", "sha256": "abc"\(grayscaleJSON) }
        """
        return try JSONDecoder().decode(PageEntry.self, from: json.data(using: .utf8)!)
    }

    func testGrayscaleFullPercentageHits() throws {
        let e = try entry(grayscaleJSON: #", "grayscale": { "percentage": 100, "whitelist": [] }"#)
        XCTAssertTrue(PageSchemaManager.grayscaleHit(e))
    }

    func testGrayscaleNoFieldHits() throws {
        let e = try entry(grayscaleJSON: "")
        XCTAssertTrue(PageSchemaManager.grayscaleHit(e))
    }

    func testGrayscaleWhitelistHits() throws {
        let dev = PageSchemaManager.deviceId
        let e = try entry(grayscaleJSON: #", "grayscale": { "percentage": 0, "whitelist": ["\#(dev)"] }"#)
        XCTAssertTrue(PageSchemaManager.grayscaleHit(e), "白名单内应命中即使百分比为 0")
    }

    func testManifestDecode() throws {
        let json = """
        { "manifestVersion": 1, "pages": [
          { "id": "me", "version": "1.0", "url": "https://x/me.json", "sha256": "abc", "minClient": 1 }
        ]}
        """
        let m = try JSONDecoder().decode(PageManifest.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(m.manifestVersion, 1)
        XCTAssertEqual(m.pages.first?.id, "me")
        XCTAssertEqual(m.pages.first?.minClient, 1)
    }
}
