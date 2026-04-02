import UIKit
import WeChatUI
import SnapKit
import ExtensionKit

public class ContactsViewController: BaseViewController {
    fileprivate struct TopItem {
        let icon: String
        let iconTint: UIColor
        let iconBackground: UIColor
        let title: String
    }

    private var sections: [String] = []
    private var grouped: [String: [Contact]] = [:]

    // 顶部功能入口
    private let topItems: [TopItem] = [
        TopItem(icon: "person.badge.plus.fill", iconTint: .white, iconBackground: UIColor(hex: "#F39B38"), title: "新的朋友"),
        TopItem(icon: "person.2.fill", iconTint: .white, iconBackground: UIColor(hex: "#4D7CFE"), title: "群聊"),
        TopItem(icon: "tag.fill", iconTint: .white, iconBackground: UIColor(hex: "#15B56B"), title: "标签"),
        TopItem(icon: "building.2.fill", iconTint: .white, iconBackground: UIColor(hex: "#5D6B86"), title: "公众号"),
    ]

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.dataSource = self
        tv.delegate = self
        tv.register(ContactCell.self, forCellReuseIdentifier: ContactCell.reuseID)
        tv.register(ContactShortcutCell.self, forCellReuseIdentifier: ContactShortcutCell.reuseID)
        tv.rowHeight = 58
        tv.backgroundColor = UIColor(hex: "#F3F4F6")
        tv.sectionIndexColor = UIColor(hex: "#576B95")
        tv.sectionIndexBackgroundColor = .clear
        tv.separatorInset = UIEdgeInsets(top: 0, left: 72, bottom: 0, right: 0)
        tv.sectionHeaderTopPadding = 4
        tv.tableHeaderView = createTableHeader()
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

    private func createTableHeader() -> UIView {
        let header = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: 92))
        header.backgroundColor = .clear

        let searchBar = UIView()
        searchBar.backgroundColor = .white
        searchBar.layer.cornerRadius = 18
        searchBar.layer.cornerCurve = .continuous

        let searchIcon = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        searchIcon.tintColor = UIColor(hex: "#8B929D")
        searchIcon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)

        let searchLabel = UILabel()
        searchLabel.text = "搜索"
        searchLabel.textColor = UIColor(hex: "#8B929D")
        searchLabel.font = .systemFont(ofSize: 15, weight: .medium)

        let summaryLabel = UILabel()
        summaryLabel.text = "共 \(sections.reduce(0) { $0 + (grouped[$1]?.count ?? 0) }) 位联系人"
        summaryLabel.textColor = UIColor(hex: "#7A818C")
        summaryLabel.font = .systemFont(ofSize: 12, weight: .medium)

        header.addSubview(searchBar)
        header.addSubview(summaryLabel)
        searchBar.addSubview(searchIcon)
        searchBar.addSubview(searchLabel)

        searchBar.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(8)
            make.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.height.equalTo(44)
        }

        searchIcon.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
        }

        searchLabel.snp.makeConstraints { make in
            make.leading.equalTo(searchIcon.snp.trailing).offset(8)
            make.centerY.equalToSuperview()
        }

        summaryLabel.snp.makeConstraints { make in
            make.leading.equalTo(searchBar)
            make.top.equalTo(searchBar.snp.bottom).offset(12)
        }

        return header
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
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: ContactShortcutCell.reuseID,
                for: indexPath
            ) as? ContactShortcutCell else {
                return UITableViewCell()
            }
            let item = topItems[indexPath.row]
            cell.configure(with: item)
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

    public func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        section == 0 ? 12 : 26
    }

    public func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard let header = view as? UITableViewHeaderFooterView else { return }
        header.tintColor = UIColor(hex: "#F3F4F6")
        header.textLabel?.textColor = UIColor(hex: "#7A818C")
        header.textLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
    }

    public func tableView(
        _ tableView: UITableView,
        willDisplay cell: UITableViewCell,
        forRowAt indexPath: IndexPath
    ) {
        cell.backgroundColor = .white
    }
}

private final class ContactShortcutCell: UITableViewCell {
    static let reuseID = "ContactShortcutCell"

    private let iconWrap = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with item: ContactsViewController.TopItem) {
        iconWrap.backgroundColor = item.iconBackground
        iconView.image = UIImage(systemName: item.icon)?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 16, weight: .bold))
        iconView.tintColor = item.iconTint
        titleLabel.text = item.title
    }

    private func setupUI() {
        accessoryType = .disclosureIndicator
        selectionStyle = .none

        iconWrap.layer.cornerRadius = 10
        iconWrap.layer.cornerCurve = .continuous

        titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = UIColor(hex: "#121417")

        contentView.addSubview(iconWrap)
        iconWrap.addSubview(iconView)
        contentView.addSubview(titleLabel)

        iconWrap.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(32)
        }

        iconView.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconWrap.snp.trailing).offset(14)
            make.centerY.equalToSuperview()
        }
    }
}
