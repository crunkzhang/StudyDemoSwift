import UIKit
import WeChatUI
import SnapKit
import WeChatRouter

public class ChatViewController: BaseViewController {
    private var conversations: [ChatConversation] = []

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.dataSource = self
        tv.delegate = self
        tv.register(ChatListCell.self, forCellReuseIdentifier: ChatListCell.reuseID)
        tv.rowHeight = 78
        tv.separatorStyle = .singleLine
        tv.separatorInset = UIEdgeInsets(top: 0, left: 74, bottom: 0, right: 14)
        tv.separatorColor = UIColor(white: 0.93, alpha: 1)
        tv.backgroundColor = UIColor(white: 0.97, alpha: 1)
        tv.tableFooterView = UIView()
        return tv
    }()

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0.97, alpha: 1)
        title = "微信"
        conversations = MockChatData.generate()
        setupTableView()
    }

    private func setupTableView() {
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

extension ChatViewController: UITableViewDataSource {
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        conversations.count
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ChatListCell.reuseID, for: indexPath) as! ChatListCell
        cell.configure(with: conversations[indexPath.row])
        return cell
    }
}

extension ChatViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let chat = conversations[indexPath.row]
        let jumplink = "\(Routes.rn)?module=ChatDetail&chatId=\(chat.id)&contactName=\(chat.contactName)"
        Router.shared.push(jumplink)
    }
}
