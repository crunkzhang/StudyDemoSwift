import Foundation
import UIKit
import Network

struct LaunchMark {
    let name: String
    let timestamp: CFAbsoluteTime
}

final class LaunchMetrics {

    static let shared = LaunchMetrics()

    private var marks: [LaunchMark] = []
    private let lock = NSLock()
    private let startTime: CFAbsoluteTime

    private init() {
        startTime = LaunchMetrics.processStartTime()
        marks.append(LaunchMark(name: "processStart", timestamp: startTime))
    }

    // MARK: - Public API

    static func mark(_ name: String) {
        let timestamp = CFAbsoluteTimeGetCurrent()
        shared.lock.lock()
        shared.marks.append(LaunchMark(name: name, timestamp: timestamp))
        shared.lock.unlock()
    }

    static func trackSDK(_ name: String, block: () -> Void) {
        mark("sdk_\(name)_start")
        block()
        mark("sdk_\(name)_end")
    }

    static func report() {
        shared.printReport()
    }

    /// 注册 RunLoop Observer，主线程第一次进入空闲即标记 firstFrame
    static func observeFirstFrame() {
        let observer = CFRunLoopObserverCreateWithHandler(
            kCFAllocatorDefault,
            CFRunLoopActivity.beforeWaiting.rawValue,  // 监听即将进入休眠
            true,   // 重复（需要手动移除）
            Int.max  // 优先级最低，确保在所有 UI 提交之后
        ) { observer, _ in
            CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, .commonModes)
            mark("firstFrame")
            // 触发 afterFirstFrame 阶段的延迟任务
            LaunchScheduler.shared.startAfterFirstFrame()
            report()
        }
        CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
    }

    // MARK: - Process Start Time (sysctl)

    private static func processStartTime() -> CFAbsoluteTime {
        var kinfo = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        sysctl(&mib, UInt32(mib.count), &kinfo, &size, nil, 0)
        let startTime = kinfo.kp_proc.p_starttime
        let unixTime = TimeInterval(startTime.tv_sec) + TimeInterval(startTime.tv_usec) / 1_000_000
        return unixTime - kCFAbsoluteTimeIntervalSince1970
    }

    // MARK: - Device Info

    private func deviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }
    }

    private func networkType() -> String {
        let semaphore = DispatchSemaphore(value: 0)
        var result = "Unknown"
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            if path.usesInterfaceType(.wifi) {
                result = "WiFi"
            } else if path.usesInterfaceType(.cellular) {
                result = "Cellular"
            } else {
                result = "None"
            }
            semaphore.signal()
        }
        let queue = DispatchQueue(label: "network.check")
        monitor.start(queue: queue)
        _ = semaphore.wait(timeout: .now() + 0.5)
        monitor.cancel()
        return result
    }

    private func totalMemoryGB() -> String {
        let bytes = ProcessInfo.processInfo.physicalMemory
        let gb = Double(bytes) / 1_073_741_824
        return String(format: "%.0fGB", gb)
    }

    private func appVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    private func isFirstLaunch() -> Bool {
        let key = "LaunchMetrics_hasLaunchedBefore"
        let launched = UserDefaults.standard.bool(forKey: key)
        if !launched {
            UserDefaults.standard.set(true, forKey: key)
        }
        return !launched
    }

    // MARK: - Report

    private func elapsed(_ from: String, _ to: String) -> Double? {
        guard let f = marks.first(where: { $0.name == from }),
              let t = marks.first(where: { $0.name == to }) else { return nil }
        return (t.timestamp - f.timestamp) * 1000
    }

    private func printReport() {
        let device = deviceModel()
        let os = UIDevice.current.systemVersion
        let net = networkType()
        let mem = totalMemoryGB()
        let ver = appVersion()
        let first = isFirstLaunch()

        let preMain = elapsed("processStart", "mainStart") ?? 0
        let mainToDid = elapsed("mainStart", "didFinishStart") ?? 0
        let sdkInit = elapsed("didFinishStart", "didFinishEnd") ?? 0
        let firstFrame = elapsed("didFinishEnd", "firstFrame") ?? 0
        let total = elapsed("processStart", "firstFrame") ?? 0

        // Collect SDK details
        var sdkDetails: [(String, Double)] = []
        let sdkStarts = marks.filter { $0.name.hasPrefix("sdk_") && $0.name.hasSuffix("_start") }
        for start in sdkStarts {
            let baseName = String(start.name.dropFirst(4).dropLast(6))
            let endName = "sdk_\(baseName)_end"
            if let ms = elapsed(start.name, endName) {
                sdkDetails.append((baseName, ms))
            }
        }

        // Format output
        let line = "══════════════════════════════════════════════════"
        let sep  = "──────────────────────────────────────────────────"

        print("╔\(line)╗")
        print("║            🚀 Launch Metrics Report              ║")
        print("╠\(line)╣")
        print("║ Device: \(pad("\(device) | iOS \(os) | \(net) | \(mem) RAM", 41))║")
        print("║ App: \(pad("\(ver) | First Launch: \(first)", 44))║")
        print("╠\(line)╣")
        print("║ Phase Breakdown:                                 ║")
        print("║   \(pad("pre-main", 20)): \(pad(ms(preMain), 7))             ║")
        print("║   \(pad("main→didFinish", 20)): \(pad(ms(mainToDid), 7))             ║")
        print("║   \(pad("SDK init", 20)): \(pad(ms(sdkInit), 7))             ║")
        print("║   \(pad("didFinish→firstFrame", 20)): \(pad(ms(firstFrame), 7))             ║")
        print("║   \(sep.prefix(35))  ║")
        print("║   \(pad("Total", 20)): \(pad(ms(total), 7))             ║")

        if !sdkDetails.isEmpty {
            print("╠\(line)╣")
            print("║ SDK Details:                                     ║")
            for (name, time) in sdkDetails {
                print("║   \(pad(name, 20)): \(pad(ms(time), 7))             ║")
            }
        }

        print("╚\(line)╝")
    }

    private func ms(_ value: Double) -> String {
        String(format: "%6.0fms", value)
    }

    private func pad(_ str: String, _ width: Int) -> String {
        str.padding(toLength: width, withPad: " ", startingAt: 0)
    }
}
