import UIKit
import React

struct ScanAlbumParams: Decodable {
    let title: String?
    var resolvedTitle: String { title ?? "从相册选取" }
}

@objc(ScanBridge)
final class ScanBridge: NSObject {

    @objc static func requiresMainQueueSetup() -> Bool { true }

    @objc func openAlbum(
        _ payload: NSDictionary,
        resolver resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        let params = payload as? [String: Any] ?? [:]
        DispatchQueue.main.async {
            let albumParams = BridgeDecode.decode(ScanAlbumParams.self, from: params)
                ?? ScanAlbumParams(title: "从相册选取")
            ScanBridgeHandler.present(
                title: albumParams.resolvedTitle,
                resolve: resolve,
                reject: reject
            )
        }
    }
}

enum ScanBridgeHandler {
    static func present(
        title: String,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        guard let viewController = RNContext.shared.currentViewController else {
            reject(BridgeError.notAvailable.rawValue, "no current view controller", nil)
            return
        }

        let alert = UIAlertController(
            title: title,
            message: "这里先用原生弹层模拟从相册识别二维码的结果回传。",
            preferredStyle: .actionSheet
        )
        alert.addAction(UIAlertAction(title: "模拟识别结果", style: .default) { _ in
            resolve([
                "source": "album",
                "content": "https://weixin.qq.com"
            ])
        })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel) { _ in
            reject(BridgeError.cancelled.rawValue, "user cancelled", nil)
        })

        viewController.present(alert, animated: true)
    }
}
