import UIKit
import WeChatUI
import SnapKit
import ExtensionKit
import WeChatRouter

public final class ContactDetailViewController: BaseViewController {
    private let contact: Contact

    private struct Item { let title: String; let detail: String? }
    private let sections: [[Item]] = [
        [Item(title: "设置备注和标签", detail: nil), Item(title: "朋友权限", detail: nil)],
        [Item(title: "朋友圈", detail: nil), Item(title: "视频号", detail: nil)],
        [Item(title: "性别", detail: "男"), Item(title: "地区", detail: "浙江 杭州")],
    ]

    private lazy var header: ContactDetailHeaderView = {
        let v = ContactDetailHeaderView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 104))
        v.configure(name: contact.name, remark: nil, wxid: contact.id, region: "浙江 杭州")
        return v
    }()

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.backgroundColor = UIColor(hex: "#EDEDED")
        tv.dataSource = self
        tv.delegate = self
        tv.tableHeaderView = header
        tv.sectionHeaderTopPadding = 0
        tv.rowHeight = 48
        tv.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
        return tv
    }()

    private lazy var actionBar: ContactDetailActionBar = {
        let bar = ContactDetailActionBar()
        bar.onMessage = { [weak self] in
            guard let self else { return }
            let name = self.contact.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? self.contact.name
            Router.shared.push("\(Routes.chatDetail)&contactName=\(name)")
        }
        bar.onCall = { [weak self] in
            let a = UIAlertController(title: "音视频通话", message: nil, preferredStyle: .actionSheet)
            a.addAction(UIAlertAction(title: "语音通话", style: .default))
            a.addAction(UIAlertAction(title: "视频通话", style: .default))
            a.addAction(UIAlertAction(title: "取消", style: .cancel))
            self?.present(a, animated: true)
        }
        return bar
    }()

    private lazy var actionBarBackdrop: UIView = {
        let v = UIView()
        v.backgroundColor = .white
        return v
    }()

    private lazy var moreItem: UIBarButtonItem = UIBarButtonItem(
        image: UIImage(systemName: "ellipsis"),
        style: .plain, target: self, action: #selector(more))

    public init(contact: Contact) {
        self.contact = contact
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(hex: "#EDEDED")
        title = ""
        navigationItem.rightBarButtonItem = moreItem

        view.addSubview(tableView)
        view.addSubview(actionBarBackdrop)
        view.addSubview(actionBar)

        actionBar.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
        }
        actionBarBackdrop.snp.makeConstraints {
            $0.leading.trailing.bottom.equalToSuperview()
            $0.top.equalTo(actionBar.snp.top)
        }
        tableView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(actionBar.snp.top)
        }
    }

    @objc private func more() {}
}

extension ContactDetailViewController: UITableViewDataSource, UITableViewDelegate {
    public func numberOfSections(in tableView: UITableView) -> Int { sections.count }
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].count }
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = sections[indexPath.section][indexPath.row]
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "cell")
        cell.textLabel?.text = item.title
        cell.textLabel?.font = .systemFont(ofSize: 17)
        cell.textLabel?.textColor = UIColor(hex: "#191919")
        cell.detailTextLabel?.text = item.detail
        cell.detailTextLabel?.textColor = UIColor(hex: "#888888")
        cell.accessoryType = .disclosureIndicator
        return cell
    }
}
