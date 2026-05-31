import UIKit
import SnapKit
import ExtensionKit

/// 把 DSLPage 渲染成 insetGrouped UITableView。
/// - profileHeader 节点 → tableHeaderView
/// - group 节点 → 一个 table section;children(cell)→ 行
/// - 未知 type → 跳过(向前兼容)
public final class DSLTableController: NSObject {

    public let tableView: UITableView
    /// 暴露头部视图,供 MeViewController 回填 live 数据(头像/状态)。
    public private(set) weak var profileHeaderView: DSLProfileHeaderView?

    private var sections: [[DSLNode]] = []   // 每个分组的 cell 节点

    public init(tableView: UITableView) {
        self.tableView = tableView
        super.init()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(DSLMenuCell.self, forCellReuseIdentifier: DSLMenuCell.reuseIdentifier)
    }

    /// 用 page 渲染。重复调用即「重渲染」(热更命中新 schema 时)。
    public func render(_ page: DSLPage) {
        if let bg = page.background { tableView.backgroundColor = UIColor(hex: bg) }

        var groups: [[DSLNode]] = []
        var headerView: DSLProfileHeaderView?

        for node in page.sections {
            switch node.type {
            case "profileHeader":
                let hv = DSLProfileHeaderView(node: node)
                hv.onTap = { DSLAction.handle(node.action) }
                headerView = hv
            case "group":
                // 仅保留已知的子组件(未知跳过)
                let cells = (node.children ?? []).filter { DSLComponentRegistry.shared.isKnown($0.type) && $0.type == "cell" }
                if !cells.isEmpty { groups.append(cells) }
            default:
                // 未知 section type → 跳过,保证老客户端不崩
                continue
            }
        }

        self.sections = groups
        if let headerView {
            headerView.frame = CGRect(x: 0, y: 0, width: tableView.bounds.width, height: DSLProfileHeaderView.preferredHeight)
            tableView.tableHeaderView = headerView
            self.profileHeaderView = headerView
        }
        tableView.reloadData()
    }
}

extension DSLTableController: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: DSLMenuCell.reuseIdentifier, for: indexPath) as? DSLMenuCell else {
            return UITableViewCell()
        }
        cell.configure(with: sections[indexPath.section][indexPath.row])
        return cell
    }
}

extension DSLTableController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        DSLAction.handle(sections[indexPath.section][indexPath.row].action)
    }

    public func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = .white
    }
}
