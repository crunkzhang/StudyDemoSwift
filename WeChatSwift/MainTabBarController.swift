import UIKit
import ExtensionKit
import ChatModule
import ContactModule
import DiscoverModule
import MeModule

class MainTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAppearance()
        setupViewControllers()
    }

    private func setupAppearance() {
        tabBar.tintColor = UIColor(hex: "#07C160")
        tabBar.backgroundColor = .white
        tabBar.isTranslucent = false
    }

    private func setupViewControllers() {
        // T12 占位:Phase 1 SessionListViewController 落地前先用占位 VC 让编译通过
        let chat = UIViewController()
        chat.view.backgroundColor = .white
        chat.title = "微信 (重构中)"
        chat.tabBarItem = UITabBarItem(
            title: "微信",
            image: UIImage(systemName: "message"),
            selectedImage: UIImage(systemName: "message.fill")
        )

        let contacts = ContactsViewController()
        contacts.tabBarItem = UITabBarItem(
            title: "通讯录",
            image: UIImage(systemName: "person.2"),
            selectedImage: UIImage(systemName: "person.2.fill")
        )

        let discover = DiscoverViewController()
        discover.tabBarItem = UITabBarItem(
            title: "发现",
            image: UIImage(systemName: "safari"),
            selectedImage: UIImage(systemName: "safari.fill")
        )

        let me = MeViewController()
        me.tabBarItem = UITabBarItem(
            title: "我",
            image: UIImage(systemName: "person.crop.circle"),
            selectedImage: UIImage(systemName: "person.crop.circle.fill")
        )

        let wrap: (UIViewController) -> UINavigationController = { rootVC in
            if #available(iOS 26, *), ProcessInfo().operatingSystemVersion.minorVersion < 2 {
                return LayoutForcingNavigationController(rootViewController: rootVC)
            }
            return UINavigationController(rootViewController: rootVC)
        }

        viewControllers = [
            wrap(chat),
            wrap(contacts),
            wrap(discover),
            wrap(me)
        ]
    }
}
