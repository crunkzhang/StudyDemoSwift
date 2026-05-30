import Foundation

// MARK: - Mock SDK Base

private func simulateWork(range: ClosedRange<UInt32>) {
    let ms = range.lowerBound + arc4random_uniform(range.upperBound - range.lowerBound + 1)
    Thread.sleep(forTimeInterval: Double(ms) / 1000.0)
}

// MARK: - 第一梯队（无依赖，必须最早）

enum CrashSDK {
    static func setup() { simulateWork(range: 30...60) }
}

enum DeviceIDSDK {
    static func setup() { simulateWork(range: 50...80) }
}

enum ConfigSDK {
    static func setup() { simulateWork(range: 60...100) }
}

// MARK: - 第二梯队（有依赖）

enum AnalyticsSDK {
    /// 依赖: DeviceIDSDK
    static func setup() { simulateWork(range: 80...150) }
}

enum PushSDK {
    /// 依赖: DeviceIDSDK
    static func setup() { simulateWork(range: 60...100) }
}

enum ABTestSDK {
    /// 依赖: AnalyticsSDK + ConfigSDK
    static func setup() { simulateWork(range: 100...200) }
}

enum ShareSDK {
    /// 依赖: DeviceIDSDK
    static func setup() { simulateWork(range: 80...130) }
}

// MARK: - 第三梯队（独立，可延后）

enum MapSDK {
    static func setup() { simulateWork(range: 150...250) }
}

enum AdSDK {
    static func setup() { simulateWork(range: 100...180) }
}

enum PaySDK {
    static func setup() { simulateWork(range: 40...70) }
}

enum ARSDK {
    static func setup() { simulateWork(range: 200...350) }
}
