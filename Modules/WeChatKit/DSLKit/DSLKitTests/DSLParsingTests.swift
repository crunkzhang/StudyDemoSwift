import XCTest
@testable import DSLKit

final class DSLParsingTests: XCTestCase {

    private let sample = """
    {
      "page": "me", "version": "1.0", "minClient": 1, "background": "#F2F3F5",
      "sections": [
        { "type": "profileHeader", "name": "用户", "wxid": "wxid_demo", "avatarColor": "#07C160", "action": "wechat://rn?page=profile" },
        { "type": "group", "children": [
          { "type": "cell", "icon": "star.fill", "iconColor": "#FA9D3B", "title": "收藏", "badge": "3", "action": "wechat://x" },
          { "type": "futureWidget", "title": "未来组件" }
        ]}
      ]
    }
    """.data(using: .utf8)!

    func testParseValidPage() throws {
        let page = try JSONDecoder().decode(DSLPage.self, from: sample)
        XCTAssertEqual(page.page, "me")
        XCTAssertEqual(page.version, "1.0")
        XCTAssertEqual(page.minClient, 1)
        XCTAssertEqual(page.background, "#F2F3F5")
        XCTAssertEqual(page.sections.count, 2)
    }

    func testPropsAccess() throws {
        let page = try JSONDecoder().decode(DSLPage.self, from: sample)
        let header = page.sections[0]
        XCTAssertEqual(header.type, "profileHeader")
        XCTAssertEqual(header.string("name"), "用户")
        XCTAssertEqual(header.action, "wechat://rn?page=profile")
        XCTAssertNil(header.string("notExist"))
    }

    func testGroupAndCell() throws {
        let page = try JSONDecoder().decode(DSLPage.self, from: sample)
        let group = page.sections[1]
        XCTAssertEqual(group.type, "group")
        XCTAssertEqual(group.children?.count, 2)
        let cell = group.children![0]
        XCTAssertEqual(cell.string("title"), "收藏")
        XCTAssertEqual(cell.string("badge"), "3")
    }

    /// 未知 type 必须被保留在模型里(由渲染器决定跳过),解析不能崩
    func testUnknownTypeTolerated() throws {
        let page = try JSONDecoder().decode(DSLPage.self, from: sample)
        let unknown = page.sections[1].children![1]
        XCTAssertEqual(unknown.type, "futureWidget")
        XCTAssertEqual(unknown.string("title"), "未来组件")
    }

    /// 组件注册表:已知 type 命中,未知不命中
    func testRegistry() {
        XCTAssertTrue(DSLComponentRegistry.shared.isKnown("cell"))
        XCTAssertTrue(DSLComponentRegistry.shared.isKnown("group"))
        XCTAssertFalse(DSLComponentRegistry.shared.isKnown("futureWidget"))
    }
}
