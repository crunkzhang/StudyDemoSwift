import XCTest
@testable import WCIMSDK

final class SeqIdManagerTests: XCTestCase {
    let key = "im.seqId.test_user"
    var mgr: SeqIdManager!

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: key)
        mgr = SeqIdManager(userId: "test_user")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: key)
        super.tearDown()
    }

    func test_initialSeqIdIsZero() {
        XCTAssertEqual(mgr.currentSeqId, 0)
    }

    func test_advance_increasesValue() {
        mgr.advance(to: 100)
        XCTAssertEqual(mgr.currentSeqId, 100)
    }

    func test_advance_doesNotGoBackwards() {
        mgr.advance(to: 100)
        mgr.advance(to: 50)
        XCTAssertEqual(mgr.currentSeqId, 100)
    }

    func test_advance_persistsToUserDefaults() {
        mgr.advance(to: 200)
        let mgr2 = SeqIdManager(userId: "test_user")
        XCTAssertEqual(mgr2.currentSeqId, 200)
    }

    func test_concurrentAdvance_neverRegresses() {
        let g = DispatchGroup()
        for i in 1...100 {
            g.enter()
            DispatchQueue.global().async {
                self.mgr.advance(to: Int64(i))
                g.leave()
            }
        }
        g.wait()
        XCTAssertGreaterThanOrEqual(mgr.currentSeqId, 1)
        XCTAssertLessThanOrEqual(mgr.currentSeqId, 100)
    }
}
