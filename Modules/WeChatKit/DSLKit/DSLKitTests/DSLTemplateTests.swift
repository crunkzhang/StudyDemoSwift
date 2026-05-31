import XCTest
@testable import DSLKit

final class DSLTemplateTests: XCTestCase {

    private func ctx() -> DSLContext {
        let json = """
        { "user": { "name": "小明", "level": 3 }, "city": "上海" }
        """.data(using: .utf8)!
        let data = try! JSONDecoder().decode(DSLValue.self, from: json)
        return DSLContext(pageData: data, injected: ["nick": .string("阿明")])
    }

    func testNestedBinding() {
        XCTAssertEqual(DSLTemplate.resolve("{{user.name}},欢迎", ctx()), "小明,欢迎")
    }
    func testNumberToString() {
        XCTAssertEqual(DSLTemplate.resolve("Lv.{{user.level}}", ctx()), "Lv.3")
    }
    func testTopLevel() {
        XCTAssertEqual(DSLTemplate.resolve("城市:{{city}}", ctx()), "城市:上海")
    }
    func testInjectedOverrides() {
        XCTAssertEqual(DSLTemplate.resolve("{{nick}}", ctx()), "阿明")
    }
    func testMissingPathEmpty() {
        XCTAssertEqual(DSLTemplate.resolve("[{{user.phone}}]", ctx()), "[]")
    }
    func testNoPlaceholderUnchanged() {
        XCTAssertEqual(DSLTemplate.resolve("纯文本", ctx()), "纯文本")
    }
    func testMultiplePlaceholders() {
        XCTAssertEqual(DSLTemplate.resolve("{{user.name}}@{{city}}", ctx()), "小明@上海")
    }

    /// 楼层页解析:title/layout/data/嵌套 grid 都正常
    func testCollectionPageParse() throws {
        let json = """
        { "page":"activity","version":"1.0","title":"活动中心","layout":"collection",
          "data": { "user": {"name":"A"} },
          "sections": [
            { "type":"banner","title":"{{user.name}}","gradient":["#FFF","#000"] },
            { "type":"grid","columns":4,"children":[ {"type":"gridItem","title":"签到"} ] }
          ] }
        """.data(using: .utf8)!
        let page = try JSONDecoder().decode(DSLPage.self, from: json)
        XCTAssertEqual(page.layout, "collection")
        XCTAssertEqual(page.title, "活动中心")
        XCTAssertEqual(page.sections.count, 2)
        XCTAssertEqual(page.sections[1].int("columns"), 4)
        XCTAssertEqual(page.sections[1].children?.first?.string("title"), "签到")
        XCTAssertEqual(page.sections[0].props["gradient"]?.arrayValue?.count, 2)
    }
}
