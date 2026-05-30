import UIKit
import Combine
import SnapKit
import WCIMSDK
import WeChatUI
import WeChatRouter
import NavigateKit

public final class ChatDetailViewController: BaseViewController, PageRoutable {

    public static var routePattern: String { "chat/detail" }

    public static func createPage(with params: [String: String]) -> UIViewController? {
        guard let sessionId = params["sessionId"] else { return nil }
        let name = params["contactName"] ?? "聊天"
        return ChatDetailViewController(sessionId: sessionId, contactName: name)
    }

    private enum Section { case main }

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.delegate = self
        tv.register(TextMessageCell.self, forCellReuseIdentifier: TextMessageCell.reuseID)
        tv.separatorStyle = .none
        tv.backgroundColor = .white
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 60
        tv.keyboardDismissMode = .interactive
        return tv
    }()

    private lazy var dataSource: UITableViewDiffableDataSource<Section, MessageCellModel> = {
        UITableViewDiffableDataSource(tableView: tableView) { tv, ip, m in
            let cell = tv.dequeueReusableCell(withIdentifier: TextMessageCell.reuseID, for: ip) as! TextMessageCell
            cell.configure(m)
            return cell
        }
    }()

    private let inputBar = ChatInputBar()
    private let logic: ChatDetailLogic
    private var cancellables = Set<AnyCancellable>()

    public init(sessionId: String, contactName: String) {
        self.logic = ChatDetailLogic(sessionId: sessionId, contactName: contactName)
        super.init(nibName: nil, bundle: nil)
        title = contactName
    }
    required init?(coder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        view.addSubview(tableView)
        view.addSubview(inputBar)
        inputBar.delegate = self

        tableView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(inputBar.snp.top)
        }
        inputBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(52)
        }

        _ = dataSource
        bind()
        logic.start()
    }

    deinit {
        logic.stop()
    }

    private func bind() {
        logic.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messages in
                self?.apply(messages)
            }
            .store(in: &cancellables)
    }

    private func apply(_ models: [MessageCellModel]) {
        var snap = NSDiffableDataSourceSnapshot<Section, MessageCellModel>()
        snap.appendSections([.main])
        snap.appendItems(models, toSection: .main)

        // 内容变更走 reconfigureItems(iOS 15+,不走 dequeue)
        let old = dataSource.snapshot()
        let oldByKey = Dictionary(uniqueKeysWithValues: old.itemIdentifiers.map { ($0.localMsgId, $0) })
        let toReconfigure = models.filter { new in
            if let oldM = oldByKey[new.localMsgId], oldM != new { return true }
            return false
        }
        if !toReconfigure.isEmpty {
            snap.reconfigureItems(toReconfigure)
        }

        dataSource.apply(snap, animatingDifferences: true) { [weak self] in
            self?.scrollToBottomIfNeeded(count: models.count)
        }
    }

    private func scrollToBottomIfNeeded(count: Int) {
        guard count > 0 else { return }
        let ip = IndexPath(row: count - 1, section: 0)
        tableView.scrollToRow(at: ip, at: .bottom, animated: true)
    }
}

extension ChatDetailViewController: ChatInputBarDelegate {
    public func inputBarDidSend(_ text: String) {
        Task { await logic.send(text) }
    }
}

extension ChatDetailViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let model = dataSource.itemIdentifier(for: indexPath) else { return }
        if model.status == .failed {
            Task { await logic.retry(model.localMsgId) }
        }
    }

    /// 滚动主线程零计算 — 高度直接读 MessageRenderCache(后台预算好)。
    /// Cache miss(刚到达还没预算)走 automaticDimension 兜底。
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let model = dataSource.itemIdentifier(for: indexPath) else {
            return UITableView.automaticDimension
        }
        return logic.renderCache.height(for: model.localMsgId) ?? UITableView.automaticDimension
    }
}
