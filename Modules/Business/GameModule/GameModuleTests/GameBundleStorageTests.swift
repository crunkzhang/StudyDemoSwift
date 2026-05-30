import XCTest
@testable import GameModule

final class GameBundleStorageTests: XCTestCase {

    var tmpDir: URL!
    var storage: GameBundleStorage!

    override func setUp() {
        super.setUp()
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        storage = GameBundleStorage(rootDir: tmpDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpDir)
        super.tearDown()
    }

    func test_gameDir_constructsExpectedPath() {
        let dir = storage.gameDir(id: "2048", version: "1.0")
        XCTAssertEqual(dir.lastPathComponent, "1.0")
        XCTAssertEqual(dir.deletingLastPathComponent().lastPathComponent, "2048")
    }

    func test_indexHTMLURL_pointsToIndexHtml() {
        let url = storage.indexHTMLURL(id: "2048", version: "1.0")
        XCTAssertEqual(url.lastPathComponent, "index.html")
    }

    func test_hasBundle_falseWhenMissing() {
        XCTAssertFalse(storage.hasBundle(id: "2048", version: "1.0"))
    }

    func test_hasBundle_trueAfterCreation() throws {
        let dir = storage.gameDir(id: "2048", version: "1.0")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("<html></html>".utf8).write(to: dir.appendingPathComponent("index.html"))
        XCTAssertTrue(storage.hasBundle(id: "2048", version: "1.0"))
    }

    func test_saveAndLoadManifest_roundTrip() throws {
        let m = GameManifest(manifestVersion: 1, updatedAt: "2026", games: [])
        try storage.saveManifest(m)
        let loaded = storage.loadManifest()
        XCTAssertEqual(loaded?.manifestVersion, 1)
    }

    func test_listVersions_sortedDescending() throws {
        for v in ["1.0", "1.1", "1.2"] {
            let dir = storage.gameDir(id: "2048", version: v)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try Data("x".utf8).write(to: dir.appendingPathComponent("index.html"))
        }
        let versions = storage.listVersions(id: "2048")
        XCTAssertEqual(versions, ["1.2", "1.1", "1.0"])
    }
}
