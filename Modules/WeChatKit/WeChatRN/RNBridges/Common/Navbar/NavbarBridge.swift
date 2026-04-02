import Foundation

private enum NavbarBridgeSignals {
    static let rightItemPress = "navbarBridge:rightItemPress"
    static let all = [rightItemPress]
}

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

    var resolvedTransparent: Bool {
        transparent ?? false
    }

    var resolvedShadowHidden: Bool {
        shadowHidden ?? false
    }
}

struct NavbarOptions: Decodable {
    let mode: NavbarMode
    let title: String?
    let animated: Bool?
    let rightItem: NavbarRightItem?
    let appearance: NavbarAppearance?

    var resolvedAnimated: Bool {
        animated ?? false
    }
}

struct NavbarGoBackParams: Decodable {
    let animated: Bool?

    var resolvedAnimated: Bool {
        animated ?? true
    }
}

@objc(NavbarBridge)
final class NavbarBridge: RNBridge, BridgeSignalProvider {
    static let bridgeSignals = NavbarBridgeSignals.all

    @objc(setOptions:)
    func setOptions(_ params: [String: Any]) {
        executeOnMain {
            self.activateEventEmitter()
            guard let navbarOptions = BridgeDecode.decode(NavbarOptions.self, from: params) else {
                return
            }
            NavbarBridgeHandler.shared.apply(options: navbarOptions)
        }
    }

    @objc(goBack:)
    func goBack(_ params: [String: Any]) {
        executeOnMain {
            self.activateEventEmitter()
            let goBackParams =
                BridgeDecode.decode(NavbarGoBackParams.self, from: params) ??
                NavbarGoBackParams(animated: true)
            NavbarBridgeHandler.shared.goBack(animated: goBackParams.resolvedAnimated)
        }
    }
}
