import Foundation
import AVFoundation
import Photos
import React

@objc(PermissionBridge)
final class PermissionBridge: NSObject {

    @objc static func requiresMainQueueSetup() -> Bool { false }

    @objc func requestCameraPermission(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: resolve("granted")
        case .denied, .restricted: resolve("denied")
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                resolve(granted ? "granted" : "denied")
            }
        @unknown default:
            resolve("denied")
        }
    }

    @objc func requestAlbumPermission(
        _ resolve: @escaping RCTPromiseResolveBlock,
        rejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        let map: (PHAuthorizationStatus) -> String = { status in
            switch status {
            case .authorized, .limited: return "granted"
            case .denied, .restricted: return "denied"
            case .notDetermined: return "denied"
            @unknown default: return "denied"
            }
        }
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                resolve(map(status))
            }
        } else {
            resolve(map(current))
        }
    }
}
