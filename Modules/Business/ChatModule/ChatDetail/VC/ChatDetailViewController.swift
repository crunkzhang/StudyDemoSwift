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
        // 与 inputBar 同色 — tableView 自己白底覆盖此色,只在 inputBar 下方
        // (home indicator 那一条)透出,视觉上消除"白底分隔"。
        view.backgroundColor = ChatInputBar.barColor
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
    /// - 集合变化(新消息/删除)→ reloadData,智能决定要不要滚底
    private func apply(_ newMessages: [MessageCellModel]) {
        let oldKeys = Set(messages.map(\.localMsgId))
        let newKeys = Set(newMessages.map(\.localMsgId))

        if oldKeys == newKeys && oldKeys.count == newMessages.count {
            // 只有内容变(发送 sending→sent / failed),用 DiffHelper 算变更索引
            let changedIndices = DiffHelper.changedIndices(
                from: messages, to: newMessages, keyedBy: \.localMsgId
            )
            messages = newMessages
            if !changedIndices.isEmpty {
                tableView.reloadRows(
                    at: changedIndices.map { IndexPath(row: $0, section: 0) },
                    with: .none
                )
            }
        } else {
            // P1-5 智能滚动:有增删 reload,但只在以下场景滚底,避免用户上滑看历史被打断:
            //  - 用户当前已经在底部(允许误差 100pt)
            //  - 或者新到的最后一条是我自己发的(我发的总是要滚到底)
            let wasNearBottom = isNearBottom
            let lastIsFromMe = newMessages.last?.isFromMe ?? false
            messages = newMessages
            tableView.reloadData()
            if wasNearBottom || lastIsFromMe {
                scrollToBottom(animated: true)
            }
        }
    }

    /// 判断当前是否在(接近)底部 — 100pt 误差,避免精确判断在 reloadData 后失准。
    private var isNearBottom: Bool {
        guard tableView.contentSize.height > tableView.bounds.height else { return true }
        let bottomY = tableView.contentSize.height - tableView.bounds.height
        return tableView.contentOffset.y >= bottomY - 100
    }

    private func scrollToBottom(animated: Bool) {
        guard !messages.isEmpty else { return }
        let ip = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: ip, at: .bottom, animated: animated)
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
            logic.retry(model.localMsgId)
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
        logic.send(text)
    }
}
