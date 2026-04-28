# 启动度量打点体系 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立覆盖 pre-main / main 后 / 首屏渲染全链路的启动度量打点体系，mock 11 个 SDK 模拟真实大厂初始化场景。

**Architecture:** LaunchMetrics 单例负责时间线记录（mark 列表）、sysctl 进程创建时间获取、设备维度采集和控制台报告输出。MockSDKs 提供 11 个模拟 SDK 供 AppDelegate 串行调用。入口从 @main 改为显式 main.swift。

**Tech Stack:** Swift 5.0, UIKit, sysctl, Network.framework (NWPathMonitor)

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `WeChatSwift/main.swift` | Create | 显式入口，记录 mainStart |
| `WeChatSwift/LaunchMetrics.swift` | Create | 核心度量类：mark / report / sysctl / 维度 |
| `WeChatSwift/MockSDKs.swift` | Create | 11 个模拟 SDK |
| `WeChatSwift/AppDelegate.swift` | Modify | 去掉 @main，加入度量打点和 mock SDK 调用 |
| `WeChatSwift/MainTabBarController.swift` | Modify | 加入 firstFrame 打点 |

---

### Task 1: LaunchMetrics 核心类

**Files:**
- Create: `WeChatSwift/LaunchMetrics.swift`

- [ ] **Step 1: 创建 LaunchMetrics.swift**

```swift
import Foundation
import Network

struct LaunchMark {
    let name: String
    let timestamp: CFAbsoluteTime
}

final class LaunchMetrics {

    static let shared = LaunchMetrics()

    private var marks: [LaunchMark] = []
    private let startTime: CFAbsoluteTime

    private init() {
        startTime = LaunchMetrics.processStartTime()
        marks.append(LaunchMark(name: "processStart", timestamp: startTime))
    }

    // MARK: - Public API

    static func mark(_ name: String) {
        shared.marks.append(LaunchMark(name: name, timestamp: CFAbsoluteTimeGetCurrent()))
    }

    static func trackSDK(_ name: String, block: () -> Void) {
        mark("sdk_\(name)_start")
        block()
        mark("sdk_\(name)_end")
    }

    static func report() {
        shared.printReport()
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
            let baseName = String(start.name.dropFirst(4).dropLast(6)) // remove "sdk_" and "_start"
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
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'generic/platform=iOS' -quiet build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add WeChatSwift/LaunchMetrics.swift
git commit -m "feat: add LaunchMetrics core class with sysctl, mark, report"
```

---

### Task 2: Mock SDKs

**Files:**
- Create: `WeChatSwift/MockSDKs.swift`

- [ ] **Step 1: 创建 MockSDKs.swift**

```swift
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
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'generic/platform=iOS' -quiet build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add WeChatSwift/MockSDKs.swift
git commit -m "feat: add 11 mock SDKs simulating real startup scenario"
```

---

### Task 3: 入口改造 — main.swift + 去掉 @main

**Files:**
- Create: `WeChatSwift/main.swift`
- Modify: `WeChatSwift/AppDelegate.swift`

- [ ] **Step 1: 创建 main.swift**

```swift
import UIKit

LaunchMetrics.mark("mainStart")

UIApplicationMain(
    CommandLine.argc,
    CommandLine.unsafeArgv,
    nil,
    NSStringFromClass(AppDelegate.self)
)
```

- [ ] **Step 2: 修改 AppDelegate.swift — 去掉 @main**

将 `AppDelegate.swift` 中的 `@main` 注解删除：

```swift
// 修改前:
@main
class AppDelegate: UIResponder, UIApplicationDelegate {

// 修改后:
class AppDelegate: UIResponder, UIApplicationDelegate {
```

- [ ] **Step 3: 编译验证**

Run: `xcodebuild -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'generic/platform=iOS' -quiet build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add WeChatSwift/main.swift WeChatSwift/AppDelegate.swift
git commit -m "feat: explicit main.swift entry point for pre-main measurement"
```

---

### Task 4: AppDelegate 集成度量打点 + Mock SDK 串行调用

**Files:**
- Modify: `WeChatSwift/AppDelegate.swift`

- [ ] **Step 1: 重写 AppDelegate.didFinishLaunchingWithOptions**

将 `AppDelegate.swift` 的完整内容替换为：

```swift
import UIKit
import WeChatRN
import ChatModule
import ContactModule
import DiscoverModule
import MeModule

class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        LaunchMetrics.mark("didFinishStart")

        // ── 原有 RN 初始化 ──
        RNFactoryManager.shared.setup()
        RNBundleManager.shared.configure(
            remoteURL: "https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com",
            appVersion: "1.0.0"
        )
        RNBundleManager.shared.start()

        // ── Mock SDK 初始化（全串行，后续任务编排优化） ──
        // 第一梯队：无依赖
        LaunchMetrics.trackSDK("CrashSDK")    { CrashSDK.setup() }
        LaunchMetrics.trackSDK("DeviceIDSDK") { DeviceIDSDK.setup() }
        LaunchMetrics.trackSDK("ConfigSDK")   { ConfigSDK.setup() }

        // 第二梯队：有依赖
        LaunchMetrics.trackSDK("AnalyticsSDK") { AnalyticsSDK.setup() }
        LaunchMetrics.trackSDK("PushSDK")      { PushSDK.setup() }
        LaunchMetrics.trackSDK("ABTestSDK")    { ABTestSDK.setup() }
        LaunchMetrics.trackSDK("ShareSDK")     { ShareSDK.setup() }

        // 第三梯队：可延后（当前仍串行，演示优化空间）
        LaunchMetrics.trackSDK("MapSDK")  { MapSDK.setup() }
        LaunchMetrics.trackSDK("AdSDK")   { AdSDK.setup() }
        LaunchMetrics.trackSDK("PaySDK")  { PaySDK.setup() }
        LaunchMetrics.trackSDK("ARSDK")   { ARSDK.setup() }

        // ── 路由注册 ──
        RNBaseViewController.registerPageRoute()
        ChatModule.registerRoutes()
        ContactModule.registerRoutes()
        DiscoverModule.registerRoutes()
        MeModule.registerRoutes()

        LaunchMetrics.mark("didFinishEnd")
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        return UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
    }
}
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'generic/platform=iOS' -quiet build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add WeChatSwift/AppDelegate.swift
git commit -m "feat: integrate launch metrics and mock SDK calls in AppDelegate"
```

---

### Task 5: MainTabBarController 首屏打点 + 触发报告

**Files:**
- Modify: `WeChatSwift/MainTabBarController.swift`

- [ ] **Step 1: 添加 viewDidAppear + firstFrame 打点**

在 `MainTabBarController` 中添加 `viewDidAppear` 方法：

```swift
// 在 MainTabBarController class 内，viewDidLoad() 方法之后添加：

private var hasReportedFirstFrame = false

override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !hasReportedFirstFrame else { return }
    hasReportedFirstFrame = true
    DispatchQueue.main.async {
        LaunchMetrics.mark("firstFrame")
        LaunchMetrics.report()
    }
}
```

- [ ] **Step 2: 编译验证**

Run: `xcodebuild -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'generic/platform=iOS' -quiet build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add WeChatSwift/MainTabBarController.swift
git commit -m "feat: add firstFrame mark and trigger report in MainTabBarController"
```

---

### Task 6: 真机运行验证

**Files:** 无文件变更，纯验证

- [ ] **Step 1: 真机运行**

在 Xcode 中选择真机设备，Run（Cmd+R）。

- [ ] **Step 2: 检查控制台输出**

在 Xcode Console 中搜索 "Launch Metrics Report"，应看到类似输出：

```
╔══════════════════════════════════════════════════╗
║            🚀 Launch Metrics Report              ║
╠══════════════════════════════════════════════════╣
║ Device: iPhone15,2 | iOS 18.0 | WiFi | 6GB RAM  ║
║ App: 1.0.0 | First Launch: false                 ║
╠══════════════════════════════════════════════════╣
║ Phase Breakdown:                                 ║
║   pre-main            :  xxxms                   ║
║   main→didFinish      :  xxxms                   ║
║   SDK init            :  xxxms                   ║
║   didFinish→firstFrame:  xxxms                   ║
║   ─────────────────────────────                  ║
║   Total               :  xxxms                   ║
╠══════════════════════════════════════════════════╣
║ SDK Details:                                     ║
║   CrashSDK            :  xxxms                   ║
║   DeviceIDSDK         :  xxxms                   ║
║   ... (11 个 SDK 各自耗时)                        ║
╚══════════════════════════════════════════════════╝
```

验证要点：
- pre-main 耗时应为正数（通常 50-300ms）
- SDK init 总耗时应在 1000-1700ms 范围（11 个 SDK 串行）
- 每个 SDK 的耗时应在其定义的范围内
- 设备信息行显示正确的机型、系统版本、网络类型

- [ ] **Step 3: 多次运行对比**

杀掉 App 重新冷启动 2-3 次，确认：
- 每次 SDK 耗时有随机波动（因为 arc4random）
- pre-main 耗时相对稳定
- 第二次启动 isFirstLaunch 变为 false
