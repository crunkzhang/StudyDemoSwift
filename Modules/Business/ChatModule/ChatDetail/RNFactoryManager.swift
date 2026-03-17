import Foundation
import React
import React_RCTAppDelegate

/// React Native Factory 协议
public protocol ReactNativeFactoryProvider: AnyObject {
    var reactNativeFactory: RCTReactNativeFactory? { get }
}

/// RN Factory 管理器
public class RNFactoryManager {
    public static let shared = RNFactoryManager()
    public weak var provider: ReactNativeFactoryProvider?

    private init() {}

    public var factory: RCTReactNativeFactory? {
        return provider?.reactNativeFactory
    }
}
