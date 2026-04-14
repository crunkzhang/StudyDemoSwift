import Foundation
import UIKit
import AVFoundation

@objc(DeviceBridge)
final class DeviceBridge: NSObject {

    @objc static func requiresMainQueueSetup() -> Bool { false }

    @objc func getAppVersion() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    @objc func getBuildNumber() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
    }

    @objc func getSystemVersion() -> String {
        UIDevice.current.systemVersion
    }

    @objc func isTorchSupported() -> NSNumber {
        let supported = AVCaptureDevice.default(for: .video)?.hasTorch ?? false
        return NSNumber(value: supported)
    }
}
