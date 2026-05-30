import UIKit
import Combine
import SnapKit
import WeChatUI
import WeChatRouter
import WCIMSDK

public final class SessionListViewController: BaseViewController {

    private enum Section { case main }

    // MARK: - Views

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.delegate = self
        tv.register(SessionListCell.self, forCellReuseIdentifier: SessionListCell.reuseID)
        tv.rowHeight = 78
        tv.separatorStyle = .singleLine
        tv.separatorInset = UIEdgeInsets(top: 0, left: 74, bottom: 0, right: 14)
        tv.separatorColor = UIColor(white: 0.93, alpha: 1)
        tv.backgroundColor = UIColor(white: 0.97, alpha: 1)
        tv.tableFooterView = UIView()
        return tv
    }()

    private lazy var dataSource: UITableViewDiffableDataSource<Section, SessionCellModel> = {
        UITableViewDiffableDataSource(tableView: tableView) { tv, indexPath, model in
            let cell = tv.dequeueReusableCell(withIdentifier: SessionListCell.reuseID, for: indexPath) as! SessionListCell
            cell.configure(model)
            return cell
        }
    }()

    private lazy var refreshControl: UIRefreshControl = {
        let rc = UIRefreshControl()
        rc.addTarget(self, action: #selector(handlePullToRefresh), for: .valueChanged)
        return rc
    }()

    private lazy var emptyView: UIView = {
        let container = UIView()
        let label = UILabel()
        label.text = "暂无会话\n点右上角 🔄 拉一条试试"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 15)
        label.textColor = UIColor(white: 0.55, alpha: 1)
        container.addSubview(label)
        label.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(40)
            make.trailing.lessThanOrEqualToSuperview().offset(-40)
        }
        return container
    }()

    // MARK: - State

    private let logic = SessionListLogic()
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupAppearance()
        setupTableView()
        setupNavigationBar()
        bind()
        logic.start()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { await logic.triggerRemoteSync() }
    }

    // MARK: - Setup

    private func setupAppearance() {
        title = "微信"
        view.backgroundColor = UIColor(white: 0.97, alpha: 1)
    }

    private func setupTableView() {
        view.addSubview(tableView)
        tableView.snp.makeConstraints { $0.edges.equalToSuperview() }
        tableView.refreshControl = refreshControl
        _ = dataSource  // 触发懒加载,绑定 tableView
    }

    private func setupNavigationBar() {
        var rightItems: [UIBarButtonItem] = [
            UIBarButtonItem(title: "🔄", style: .plain, target: self, action: #selector(manualSync))
        ]
        #if DEBUG
        rightItems.append(contentsOf: debugBarItems)
        #endif
        navigationItem.rightBarButtonItems = rightItems
    }

    // MARK: - Actions

    @objc private func manualSync() {
        Task { await logic.triggerRemoteSync(force: true) }
    }

    @objc private func handlePullToRefresh() {
        Task {
            await logic.triggerRemoteSync(force: true)
            // 至少转 0.3s,体验更自然(避免一闪而过)
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run { self.refreshControl.endRefreshing() }
        }
    }

    // MARK: - Binding

    private func bind() {
        logic.$sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.applySnapshot(sessions)
                self?.updateEmptyView(isEmpty: sessions.isEmpty)
            }
            .store(in: &cancellables)
    }

    private func updateEmptyView(isEmpty: Bool) {
        tableView.backgroundView = isEmpty ? emptyView : nil
    }

    /// DiffableDataSource diff + iOS 15 reconfigureItems 让屏幕上的 cell 原地刷,
    /// 不走 dequeue,头像不重下、滚动不跳。
    private func applySnapshot(_ models: [SessionCellModel]) {
        var snap = NSDiffableDataSourceSnapshot<Section, SessionCellModel>()
        snap.appendSections([.main])
        snap.appendItems(models, toSection: .main)

        // 用 DiffHelper 找出内容变了的索引,转回 model 数组做 reconfigure
        let oldItems = dataSource.snapshot().itemIdentifiers
        let changedIndices = DiffHelper.changedIndices(
            from: oldItems, to: models, keyedBy: \.sessionId
        )
        let toReconfigure = changedIndices.map { models[$0] }
        if !toReconfigure.isEmpty {
            snap.reconfigureItems(toReconfigure)
        }

        dataSource.apply(snap, animatingDifferences: true)
    }
}

// MARK: - UITableViewDelegate

extension SessionListViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let model = dataSource.itemIdentifier(for: indexPath) else { return }
        let encodedName = model.contactName.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) ?? ""
        let url = "\(Routes.chatDetail)?sessionId=\(model.sessionId)&contactName=\(encodedName)"
        Router.shared.push(url)
    }
}

// MARK: - Debug (P2-11 集中所有 DEBUG-only 代码)

#if DEBUG
private extension SessionListViewController {
    var debugBarItems: [UIBarButtonItem] {
        [UIBarButtonItem(title: "🗑️", style: .plain, target: self, action: #selector(wipeAndReload))]
    }

    @objc func wipeAndReload() {
        WCIMSDK.clearLocalData()
        logic.reloadFromDB()
        print("[Debug] 🗑️ 已清空。点 🔄 / 下拉刷新每次会带 1~3 条新消息进来")
    }
}
#endif
