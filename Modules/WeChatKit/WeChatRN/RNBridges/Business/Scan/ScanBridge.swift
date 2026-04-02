import Foundation

private enum ScanBridgeSignals {
    static let albumResult = "scanBridge:albumResult"
    static let all = [albumResult]
}

struct ScanAlbumParams: Decodable {
    let title: String?

    var resolvedTitle: String {
        title ?? "从相册选取"
    }
}

@objc(ScanBridge)
final class ScanBridge: RNBridge, BridgeSignalProvider {
    static let bridgeSignals = ScanBridgeSignals.all

    @objc(openAlbum:)
    func openAlbum(_ params: [String: Any]) {
        executeOnMain {
            self.activateEventEmitter()
            let albumParams =
                BridgeDecode.decode(ScanAlbumParams.self, from: params) ??
                ScanAlbumParams(title: "从相册选取")
            ScanBridgeHandler.shared.openAlbum(title: albumParams.resolvedTitle)
        }
    }
}
