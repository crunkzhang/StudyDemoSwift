import UIKit
import Combine
import SnapKit
import WeChatUI
import WCIMSDK

public final class SessionListViewController: BaseViewController {

    private enum Section { case main }

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

    private let logic = SessionListLogic()
    private var cancellables = Set<AnyCancellable>()

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "微信"
        view.backgroundColor = UIColor(white: 0.97, alpha: 1)

        view.addSubview(tableView)
        tableView.snp.makeConstraints { $0.edges.equalToSuperview() }
        _ = dataSource

        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "🔄", style: .plain, target: self, action: #selector(manualSync)
        )

        bind()
        logic.start()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { await logic.triggerRemoteSync() }
    }

    @objc private func manualSync() {
        Task { await logic.triggerRemoteSync() }
    }

    private func bind() {
        logic.$sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.applySnapshot(sessions)
            }
            .store(in: &cancellables)
    }

    /// 关键:DiffableDataSource diff + iOS 15 reconfigureItems 让屏幕上的 cell 原地刷,
    /// 不走 dequeue,头像不重下、滚动不跳。
    private func applySnapshot(_ models: [SessionCellModel]) {
        var snap = NSDiffableDataSourceSnapshot<Section, SessionCellModel>()
        snap.appendSections([.main])
        snap.appendItems(models, toSection: .main)

        let oldSnap = dataSource.snapshot()
        let oldByKey = Dictionary(uniqueKeysWithValues: oldSnap.itemIdentifiers.map { ($0.sessionId, $0) })
        let toReconfigure = models.filter { new in
            if let old = oldByKey[new.sessionId], old != new { return true }
            return false
        }
        if !toReconfigure.isEmpty {
            snap.reconfigureItems(toReconfigure)
        }

        dataSource.apply(snap, animatingDifferences: true)
    }
}

extension SessionListViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // Phase 1:点击只 log;详情页 Phase 2 接入
        if let model = dataSource.itemIdentifier(for: indexPath) {
            print("[SessionList] 点击会话: \(model.sessionId) - \(model.contactName)")
        }
    }
}
