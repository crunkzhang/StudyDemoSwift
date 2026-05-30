import XCTest
@testable import GameModule

final class GameManifestTests: XCTestCase {

    func test_decode_validManifest() throws {
        let json = """
        {
          "manifestVersion": 1,
          "updatedAt": "2026-05-30T20:00:00Z",
          "games": [
            {
              "id": "2048", "title": "2048",
              "icon": "https://example.com/icon.png",
              "version": "1.0",
              "url": "https://example.com/2048-v1.0.zip",
              "sha256": "abc123",
              "size": 12345,
              "grayscale": { "percentage": 100, "whitelist": [] }
            }
          ]
        }
        """.data(using: .utf8)!
        let m = try JSONDecoder().decode(GameManifest.self, from: json)
        XCTAssertEqual(m.manifestVersion, 1)
        XCTAssertEqual(m.games.count, 1)
        XCTAssertEqual(m.games[0].id, "2048")
        XCTAssertEqual(m.games[0].sha256, "abc123")
        XCTAssertEqual(m.games[0].grayscale?.percentage, 100)
    }

    func test_decode_missingGrayscale_defaultsNil() throws {
        let json = """
        {
          "manifestVersion": 1, "updatedAt": "2026", "games": [{
            "id": "2048", "title": "2048", "icon": "x",
            "version": "1.0", "url": "x", "sha256": "x", "size": 1
          }]
        }
        """.data(using: .utf8)!
        let m = try JSONDecoder().decode(GameManifest.self, from: json)
        XCTAssertNil(m.games[0].grayscale)
    }
}
