import XCTest
@testable import WCIMSDK

final class SendQueueManagerTests: XCTestCase {
    var mgr: SendQueueManager!

    override func setUp() {
        super.setUp()
        mgr = SendQueueManager()
    }

    func test_sameSession_returnsSameQueue() {
        XCTAssertTrue(mgr.queue(for: "s1") === mgr.queue(for: "s1"))
    }

    func test_differentSessions_returnDifferentQueues() {
        XCTAssertFalse(mgr.queue(for: "s1") === mgr.queue(for: "s2"))
    }

    func test_sameSessionQueue_executesSerially() {
        let q = mgr.queue(for: "s1")
        let lock = NSLock()
        var order: [Int] = []
        let g = DispatchGroup()
        for i in 1...10 {
            g.enter()
            q.async {
                Thread.sleep(forTimeInterval: 0.005)
                lock.lock(); order.append(i); lock.unlock()
                g.leave()
            }
        }
        g.wait()
        XCTAssertEqual(order, Array(1...10))
    }
}
