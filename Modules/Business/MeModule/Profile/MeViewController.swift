import UIKit
import WeChatUI
import SnapKit
import ExtensionKit
import WeChatRouter
import WeChatNetAPI
import DSLKit

/// 「我的」页:整页由 DSL(me.json)驱动渲染。
/// - 结构(头部 + 菜单分组)来自 schema,支持 OSS 热更
/// - 头像图片 / 状态文案的 live 数据仍由 MeProfileService 异步回填到 DSL 头部
public class MeViewController: BaseViewController {

    private let profileService = MeProfileService()
    private static let avatarImageCache = NSCache<NSString, UIImage>()
    private var representedAvatarURL: String?

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .insetGrouped)
        tv.backgroundColor = UIColor(hex: "#F2F3F5")
        tv.separatorStyle = .singleLine
        tv.separatorColor = UIColor(hex: "#E7E8EB")
        tv.rowHeight = 62
        tv.sectionHeaderHeight = 14
        tv.sectionFooterHeight = 0.01
        tv.contentInset = UIEdgeInsets(top: 4, left: 0, bottom: 24, right: 0)
        return tv
    }()

    private lazy var renderer = DSLTableController(tableView: tableView)

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(hex: "#F2F3F5")
        view.addSubview(tableView)
        tableView.snp.makeConstraints { $0.edges.equalToSuperview() }
        renderPage()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        loadProfileStatus()
        // 热更:后台拉一次 schema,有更新就重渲染
        Task {
            await PageSchemaManager.shared.refresh()
            await MainActor.run {
                self.renderPage()
                self.loadProfileStatus()
            }
        }
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    private func renderPage() {
        guard let page = PageSchemaManager.shared.page(for: "me") else { return }
        renderer.render(page)
    }

    // MARK: - live 数据回填到 DSL 头部

    private func loadProfileStatus() {
        Task { [weak self] in
            guard let self else { return }
            let header = await profileService.fetchHeaderData()
            await MainActor.run {
                self.renderer.profileHeaderView?.updateStatus(header.statusText)
                self.updateAvatar(with: header.avatarURL)
            }
        }
    }

    private func updateAvatar(with url: URL?) {
        renderer.profileHeaderView?.updateAvatar(nil)
        representedAvatarURL = url?.absoluteString
        guard let url else { return }
        let urlString = url.absoluteString

        if let cached = Self.avatarImageCache.object(forKey: urlString as NSString) {
            renderer.profileHeaderView?.updateAvatar(cached)
            return
        }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let self, let data, let image = UIImage(data: data) else { return }
            Self.avatarImageCache.setObject(image, forKey: urlString as NSString)
            DispatchQueue.main.async {
                guard self.representedAvatarURL == urlString else { return }
                self.renderer.profileHeaderView?.updateAvatar(image)
            }
        }.resume()
    }
}
