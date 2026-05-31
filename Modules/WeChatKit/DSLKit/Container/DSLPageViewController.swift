import UIKit
import SnapKit
import WeChatUI
import WeChatRouter
import NavigateKit
import ExtensionKit

/// 通用 DSL 页容器:按 schema 的 layout 自动选「列表型」或「楼层型」渲染。
/// 路由:wechat://page?id=xxx
public final class DSLPageViewController: BaseViewController, PageRoutable {

    public static var routePattern: String { "page" }
    public static func createPage(with params: [String: String]) -> UIViewController? {
        guard let id = params["id"] else { return nil }
        return DSLPageViewController(pageId: id)
    }

    private let pageId: String
    private var tableController: DSLTableController?
    private var collectionController: DSLCollectionController?

    public init(pageId: String) {
        self.pageId = pageId
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(hex: "#F2F3F5")
        renderPage()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 热更:拉一次,变了重渲染
        Task {
            await PageSchemaManager.shared.refresh()
            await MainActor.run { self.renderPage() }
        }
    }

    private func renderPage() {
        guard let page = PageSchemaManager.shared.page(for: pageId) else { return }
        if let t = page.title { title = t }

        if page.layout == "collection" {
            if collectionController == nil {
                let cc = DSLCollectionController()
                view.addSubview(cc.collectionView)
                cc.collectionView.snp.makeConstraints { $0.edges.equalToSuperview() }
                collectionController = cc
            }
            collectionController?.render(page)
        } else {
            if tableController == nil {
                let tv = UITableView(frame: .zero, style: .insetGrouped)
                tv.backgroundColor = UIColor(hex: "#F2F3F5")
                tv.separatorColor = UIColor(hex: "#E7E8EB")
                tv.rowHeight = 62
                tv.sectionHeaderHeight = 14
                tv.sectionFooterHeight = 0.01
                view.addSubview(tv)
                tv.snp.makeConstraints { $0.edges.equalToSuperview() }
                tableController = DSLTableController(tableView: tv)
            }
            tableController?.render(page)
        }
    }
}
