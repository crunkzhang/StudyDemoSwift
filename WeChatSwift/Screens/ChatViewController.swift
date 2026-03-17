import UIKit
import SnapKit
import RouterKit
import WeChatRouter

class ChatViewController: UIViewController {
    private var conversations: [ChatConversation] = []

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.dataSource = self
        tv.delegate = self
        tv.register(ChatListCell.self, forCellReuseIdentifier: ChatListCell.reuseID)
        tv.rowHeight = 64
        tv.separatorInset = UIEdgeInsets(top: 0, left: 62, bottom: 0, right: 0)
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
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
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        conversations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ChatListCell.reuseID, for: indexPath) as! ChatListCell
        cell.configure(with: conversations[indexPath.row])
        return cell
    }
}

extension ChatViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let chat = conversations[indexPath.row]
        Router.shared.push("\(Routes.chatDetail)?chatId=\(chat.id)&contactName=\(chat.contactName)")
    }
}
