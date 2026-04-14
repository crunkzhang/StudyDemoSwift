import UIKit

enum NavbarMode: String, Decodable {
    case native
    case rn
}

struct NavbarRightItem: Decodable {
    let title: String
    let actionId: String
}

struct NavbarAppearance: Decodable {
    let transparent: Bool?
    let backgroundColor: String?
    let tintColor: String?
    let titleColor: String?
    let shadowHidden: Bool?

    var resolvedTransparent: Bool { transparent ?? false }
    var resolvedShadowHidden: Bool { shadowHidden ?? false }
}

struct NavbarOptions: Decodable {
    let mode: NavbarMode
    let title: String?
    let animated: Bool?
    let rightItem: NavbarRightItem?
    let appearance: NavbarAppearance?

    var resolvedAnimated: Bool { animated ?? false }
}

@objc(NavbarBridge)
final class NavbarBridge: NSObject {

    @objc static func requiresMainQueueSetup() -> Bool { true }

    @objc func setOptions(_ payload: NSDictionary) {
        let params = payload as? [String: Any] ?? [:]
        DispatchQueue.main.async {
            guard let options = BridgeDecode.decode(NavbarOptions.self, from: params) else { return }
            RNNavbarService.shared.apply(options: options)
        }
    }

}
