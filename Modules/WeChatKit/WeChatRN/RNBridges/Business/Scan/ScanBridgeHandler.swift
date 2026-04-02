import UIKit

private enum ScanBridgeSignals {
    static let albumResult = "scanBridge:albumResult"
}

final class ScanBridgeHandler {
    static let shared = ScanBridgeHandler()

    private init() {}

    func openAlbum(title: String) {
        guard let viewController = RNBridgeContext.shared.currentViewController else {
            return
        }

        let alert = UIAlertController(
            title: title,
            message: "这里先用原生弹层模拟从相册识别二维码的结果回传。",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "模拟识别结果", style: .default, handler: { _ in
            RNBridgeContext.shared.emit(
                signal: ScanBridgeSignals.albumResult,
                payload: [
                    "source": "album",
                    "content": "https://weixin.qq.com"
                ]
            )
        }))
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))

        viewController.present(alert, animated: true)
    }
}
