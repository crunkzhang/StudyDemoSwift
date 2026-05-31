import XCTest
@testable import DSLKit

final class GrayscaleTests: XCTestCase {

    private func entry(id: String, percentage: Int, whitelist: [String] = []) throws -> PageEntry {
        let wl = whitelist.map { "\"\($0)\"" }.joined(separator: ",")
        let json = """
        { "id": "\(id)", "version": "1.0", "url": "https://x/\(id).json", "sha256": "abc",
          "grayscale": { "percentage": \(percentage), "whitelist": [\(wl)] } }
        """
        return try JSONDecoder().decode(PageEntry.self, from: json.data(using: .utf8)!)
    }

    func testFullAndZero() throws {
        XCTAssertTrue(Grayscale.hit(try entry(id: "p", percentage: 100), deviceId: "dev"))
        XCTAssertFalse(Grayscale.hit(try entry(id: "p", percentage: 0), deviceId: "dev"))
    }

    func testWhitelistBeatsZero() throws {
        XCTAssertTrue(Grayscale.hit(try entry(id: "p", percentage: 0, whitelist: ["dev"]), deviceId: "dev"))
    }

    func testNoGrayscaleAlwaysHits() throws {
        let e = try JSONDecoder().decode(PageEntry.self, from:
            #"{"id":"p","version":"1.0","url":"https://x","sha256":"a"}"#.data(using: .utf8)!)
        XCTAssertTrue(Grayscale.hit(e, deviceId: "dev"))
    }

    /// 按页独立:同一设备在不同页面的灰度桶相互无关
    func testPerPageIndependence() {
        let dev = "device-ABC"
        XCTAssertNotEqual(Grayscale.fnv1a("\(dev):pageA"), Grayscale.fnv1a("\(dev):pageB"))
    }

    /// 分布均匀:1 万个设备在 30% 灰度下,命中率应接近 30%(±3%)
    func testDistributionApprox30() throws {
        let e = try entry(id: "promo", percentage: 30)
        var hits = 0
        let n = 10_000
        for i in 0..<n {
            if Grayscale.hit(e, deviceId: "dev-\(i)-\(UUID().uuidString.prefix(4))") { hits += 1 }
        }
        let rate = Double(hits) / Double(n)
        XCTAssertEqual(rate, 0.30, accuracy: 0.03, "命中率 \(rate) 偏离 30% 太多,哈希分布不均")
    }
}
