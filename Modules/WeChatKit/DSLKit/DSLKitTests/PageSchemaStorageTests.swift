import XCTest
@testable import DSLKit

final class PageSchemaStorageTests: XCTestCase {

    private func makeStorage() -> PageSchemaStorage {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("DSLPagesTest-\(UUID().uuidString)")
        return PageSchemaStorage(rootDir: tmp)
    }

    func testSaveAndRead() {
        let s = makeStorage()
        s.save(id: "me", data: Data("v1".utf8), version: "1.0")
        XCTAssertEqual(s.currentVersion("me"), "1.0")
        XCTAssertEqual(s.currentData("me"), Data("v1".utf8))
    }

    func testSaveKeepsPreviousVersion() {
        let s = makeStorage()
        s.save(id: "me", data: Data("v1".utf8), version: "1.0")
        s.save(id: "me", data: Data("v2".utf8), version: "1.1")
        XCTAssertEqual(s.currentVersion("me"), "1.1")
        XCTAssertEqual(s.currentData("me"), Data("v2".utf8))
        XCTAssertEqual(s.previousVersion("me"), "1.0")
        XCTAssertEqual(s.previousData("me"), Data("v1".utf8))
    }

    func testRollbackRestoresPrevious() {
        let s = makeStorage()
        s.save(id: "me", data: Data("v1".utf8), version: "1.0")
        s.save(id: "me", data: Data("v2".utf8), version: "1.1")
        XCTAssertTrue(s.rollback(id: "me"))
        XCTAssertEqual(s.currentVersion("me"), "1.0")
        XCTAssertEqual(s.currentData("me"), Data("v1".utf8))
        // 回滚后上一版被清掉,再次回滚无对象
        XCTAssertNil(s.previousData("me"))
        XCTAssertFalse(s.rollback(id: "me"))
    }

    func testRollbackWithoutPreviousFails() {
        let s = makeStorage()
        s.save(id: "me", data: Data("v1".utf8), version: "1.0")
        XCTAssertFalse(s.rollback(id: "me"))   // 只有一个版本,无上一版
    }
}
