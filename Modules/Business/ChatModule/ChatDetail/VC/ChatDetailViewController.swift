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

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.dataSource = self
        tv.delegate = self
        tv.register(TextMessageCell.self, forCellReuseIdentifier: TextMessageCell.reuseID)
        tv.separatorStyle = .none
        tv.backgroundColor = .white
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 60
        tv.keyboardDismissMode = .interactive
        return tv
    }()

    private let inputBar = ChatInputBar()
    private let logic: ChatDetailLogic
    private var cancellables = Set<AnyCancellable>()

    /// 当前数据源(主线程访问)
    private var messages: [MessageCellModel] = []

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

        // 点上方区域收键盘 — cancelsTouchesInView=false 不影响 cell 点击/重发
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        tableView.addGestureRecognizer(tap)

        tableView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(inputBar.snp.top)
        }
        // iOS 15+ keyboardLayoutGuide.top:键盘收起时贴 safeArea 底部,弹起时贴键盘顶部,
        // 拖拽收起(keyboardDismissMode=.interactive)也跟手势同步,无需手动监听 notification。
        inputBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.keyboardLayoutGuide.snp.top)
            make.height.equalTo(52)
        }

        bind()
        logic.start()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 进会话即"已读" — SessionList 红点消失
        logic.markAllRead()
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    deinit {
        logic.stop()
    }

    private func bind() {
        logic.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newMessages in
                self?.apply(newMessages)
            }
            .store(in: &cancellables)
    }

    /// 简单 id-keyed diff:
    /// - 同一组 id 集合 → 只是 status 变化,逐条 reloadRows 不动滚动
    /// - 集合变化(新消息/删除)→ reloadData + 滚到底
    private func apply(_ newMessages: [MessageCellModel]) {
        let oldKeys = Set(messages.map(\.localMsgId))
        let newKeys = Set(newMessages.map(\.localMsgId))

        if oldKeys == newKeys && oldKeys.count == newMessages.count {
            // 只有内容变(发送 sending→sent / failed),逐条 reloadRows
            let oldByKey = Dictionary(uniqueKeysWithValues: messages.map { ($0.localMsgId, $0) })
            let changedIndices = newMessages.enumerated().compactMap { i, m -> Int? in
                guard let oldM = oldByKey[m.localMsgId], oldM != m else { return nil }
                return i
            }
            messages = newMessages
            if !changedIndices.isEmpty {
                tableView.reloadRows(
                    at: changedIndices.map { IndexPath(row: $0, section: 0) },
                    with: .none
                )
            }
        } else {
            // 有增删,全量 reload + 滚到底
            messages = newMessages
            tableView.reloadData()
            scrollToBottomIfNeeded()
        }
    }

    private func scrollToBottomIfNeeded() {
        guard !messages.isEmpty else { return }
        let ip = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: ip, at: .bottom, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension ChatDetailViewController: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        messages.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: TextMessageCell.reuseID, for: indexPath) as! TextMessageCell
        cell.configure(messages[indexPath.row])
        return cell
    }
}

// MARK: - UITableViewDelegate

extension ChatDetailViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard indexPath.row < messages.count else { return }
        let model = messages[indexPath.row]
        if model.status == .failed {
            Task { await logic.retry(model.localMsgId) }
        }
    }

    /// 滚动主线程零计算 — 高度直接读 MessageRenderCache(后台预算好)。
    public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard indexPath.row < messages.count else { return UITableView.automaticDimension }
        let model = messages[indexPath.row]
        return logic.renderCache.height(for: model.localMsgId) ?? UITableView.automaticDimension
    }
}

// MARK: - ChatInputBarDelegate

extension ChatDetailViewController: ChatInputBarDelegate {
    public func inputBarDidSend(_ text: String) {
        Task { await logic.send(text) }
    }
}
