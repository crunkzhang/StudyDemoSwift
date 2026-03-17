import UIKit
import SnapKit
import ExtensionKit

public class ContactsViewController: UIViewController {
    private var sections: [String] = []
    private var grouped: [String: [Contact]] = [:]

    // 顶部功能入口
    private let topItems: [(icon: String, title: String)] = [
        ("person.badge.plus", "新的朋友"),
        ("person.2", "群聊"),
        ("tag", "标签"),
        ("building.2", "公众号"),
    ]

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.dataSource = self
        tv.delegate = self
        tv.register(ContactCell.self, forCellReuseIdentifier: ContactCell.reuseID)
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "TopItemCell")
        tv.rowHeight = 52
        tv.sectionIndexColor = UIColor(hex: "#576B95")
        tv.sectionIndexBackgroundColor = .clear
        tv.separatorInset = UIEdgeInsets(top: 0, left: 58, bottom: 0, right: 0)
        return tv
    }()

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        title = "通讯录"
        navigationController?.navigationBar.prefersLargeTitles = false

        let data = MockContactData.generate()
        sections = data.sections
        grouped = data.grouped

        setupTableView()
    }

    private func setupTableView() {
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

// MARK: - UITableViewDataSource
extension ContactsViewController: UITableViewDataSource {
    public func numberOfSections(in tableView: UITableView) -> Int {
        1 + sections.count // section 0 = top items
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 { return topItems.count }
        let key = sections[section - 1]
        return grouped[key]?.count ?? 0
    }

    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "TopItemCell", for: indexPath)
            var config = cell.defaultContentConfiguration()
            let item = topItems[indexPath.row]
            config.image = UIImage(systemName: item.icon)
            config.imageProperties.tintColor = UIColor(hex: "#576B95")
            config.text = item.title
            config.textProperties.font = .systemFont(ofSize: 16)
            cell.contentConfiguration = config
            cell.accessoryType = .none
            return cell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: ContactCell.reuseID, for: indexPath) as! ContactCell
        let key = sections[indexPath.section - 1]
        if let contact = grouped[key]?[indexPath.row] {
            cell.configure(with: contact)
        }
        return cell
    }

    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 { return nil }
        return sections[section - 1]
    }

    public func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return sections
    }

    public func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        return index + 1
    }
}

// MARK: - UITableViewDelegate
extension ContactsViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
