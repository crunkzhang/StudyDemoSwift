# 启动度量打点体系设计

## 目标

为 WeChatSwift 项目建立启动度量打点体系，覆盖 pre-main / main 后 / 首屏渲染全链路，支持 SDK 级耗时分析和设备维度采集。同时 mock 真实大厂 SDK 初始化场景，为后续任务编排实操铺路。

## 架构

```
┌─────────────────────────────────────────────┐
│  打点层（调用方）                              │
│  main.swift / AppDelegate / VC              │
│  → LaunchMetrics.mark("xxx")                │
├─────────────────────────────────────────────┤
│  核心层（LaunchMetrics）                      │
│  - 时间线记录（有序 mark 列表）                 │
│  - 进程创建时间（sysctl）                      │
│  - 设备维度采集（机型/网络/内存）                │
│  - 报告生成                                   │
├─────────────────────────────────────────────┤
│  输出层                                       │
│  - Console 结构化日志                          │
│  - （预留）APM 上报接口                        │
└─────────────────────────────────────────────┘
```

代码全部放壳工程 `WeChatSwift/` 目录下，不新建 pod。

### 文件结构

| 文件 | 职责 |
|------|------|
| `WeChatSwift/main.swift` | 新入口，记录 mainStart，调用 UIApplicationMain |
| `WeChatSwift/LaunchMetrics.swift` | 核心类：mark / report / sysctl / 维度采集 |
| `WeChatSwift/MockSDKs.swift` | 11 个模拟 SDK，有随机耗时和依赖关系 |

## 入口改造

去掉 AppDelegate 上的 `@main` 注解，新建 `main.swift` 作为显式入口：

```swift
// main.swift
import UIKit

LaunchMetrics.mark("mainStart")
UIApplicationMain(
    CommandLine.argc,
    CommandLine.unsafeArgv,
    nil,
    NSStringFromClass(AppDelegate.self)
)
```

目的是在代码最早执行处记录时间戳，与 sysctl 取到的进程创建时间配合计算 pre-main 耗时。

## 阶段划分

### 打点时间线

按启动流程顺序定义 mark 点：

```
T0  processStart      ← sysctl 进程创建时间（pre-main 起点）
T1  mainStart          ← main.swift 第一行（pre-main 终点）
T2  didFinishStart     ← didFinishLaunchingWithOptions 第一行
T3  sdk_XXX_start/end  ← 每个 SDK 初始化前后（多组）
T4  didFinishEnd       ← didFinishLaunchingWithOptions return 前
T5  firstFrame         ← MainTabBarController.viewDidAppear + DispatchQueue.main.async
```

### 阶段耗时计算

| 阶段 | 起点 | 终点 | 含义 |
|------|------|------|------|
| pre-main | T0 processStart | T1 mainStart | dyld 加载 + rebase/bind + initializer |
| main→didFinish | T1 mainStart | T2 didFinishStart | runtime 到 AppDelegate 回调 |
| SDK 初始化 | T2 didFinishStart | T4 didFinishEnd | 所有 SDK 初始化耗时 |
| 首屏渲染 | T4 didFinishEnd | T5 firstFrame | 首屏 UI 创建到可见 |
| **总启动耗时** | T0 processStart | T5 firstFrame | 用户感知的完整冷启动 |

### 首屏终点方案

使用 `viewDidAppear` + 下一个 RunLoop 回调：

```swift
// MainTabBarController
override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    DispatchQueue.main.async {
        LaunchMetrics.mark("firstFrame")
        LaunchMetrics.report()
    }
}
```

`DispatchQueue.main.async` 确保在当前 RunLoop 的渲染提交之后才标记，比纯 `viewDidAppear` 更接近用户真实感知。用 `once` 标记防止重复触发。

## LaunchMetrics 核心类

### mark 数据结构

```swift
struct LaunchMark {
    let name: String
    let timestamp: CFAbsoluteTime
}
```

### 核心 API

```swift
final class LaunchMetrics {
    /// 记录一个时间点
    static func mark(_ name: String)

    /// 记录 SDK 初始化（自动生成 start/end 两个 mark）
    static func trackSDK(_ name: String, block: () -> Void)

    /// 输出完整报告到控制台
    static func report()
}
```

### pre-main 时间获取

通过 `sysctl` 系统调用获取进程创建时间：

```swift
static var processStartTime: CFAbsoluteTime {
    var kinfo = kinfo_proc()
    var size = MemoryLayout<kinfo_proc>.stride
    var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
    sysctl(&mib, UInt32(mib.count), &kinfo, &size, nil, 0)
    let startTime = kinfo.kp_proc.p_starttime
    return CFAbsoluteTime(startTime.tv_sec) + CFAbsoluteTime(startTime.tv_usec) / 1_000_000
         - kCFAbsoluteTimeIntervalSince1970
}
```

## 设备维度采集

每次启动记录附带维度信息，用于线上按维度聚合分析：

| 字段 | 来源 | 示例 |
|------|------|------|
| deviceModel | `utsname` / machine | iPhone15,2 |
| osVersion | `UIDevice.current.systemVersion` | 18.0 |
| appVersion | `Bundle.main` infoDictionary | 1.0.0 |
| networkType | `NWPathMonitor` | WiFi / Cellular / None |
| totalMemory | `ProcessInfo.physicalMemory` | 6GB |
| isFirstLaunch | UserDefaults 标记 | true / false |

维度信息在报告头部展示，线上场景随耗时数据一起上报 APM 后台。

## Mock SDK 设计

模拟真实大厂电商 App 的 SDK 初始化场景，11 个 SDK 分三个梯队。

### SDK 列表

**第一梯队（无依赖，必须最早）：**

| SDK | 职责 | 耗时范围 | 依赖 |
|-----|------|---------|------|
| CrashSDK | 崩溃监控 | 30-60ms | 无 |
| DeviceIDSDK | 设备ID生成 | 50-80ms | 无 |
| ConfigSDK | 远程配置/Feature Flag | 60-100ms | 无 |

**第二梯队（有依赖）：**

| SDK | 职责 | 耗时范围 | 依赖 |
|-----|------|---------|------|
| AnalyticsSDK | 埋点 | 80-150ms | DeviceID |
| PushSDK | 推送 | 60-100ms | DeviceID |
| ABTestSDK | AB实验 | 100-200ms | Analytics + Config |
| ShareSDK | 分享 | 80-130ms | DeviceID |

**第三梯队（独立，可延后）：**

| SDK | 职责 | 耗时范围 | 依赖 |
|-----|------|---------|------|
| MapSDK | 地图/定位 | 150-250ms | 无 |
| AdSDK | 广告 | 100-180ms | 无 |
| PaySDK | 支付 | 40-70ms | 无 |
| ARSDK | AR虚拟试穿 | 200-350ms | 无 |

### 依赖关系图

```
CrashSDK ──────────────────────────────── (独立)
DeviceIDSDK ──┬── AnalyticsSDK ──┐
              ├── PushSDK        ├── ABTestSDK
              └── ShareSDK       │
ConfigSDK ───────────────────────┘
MapSDK / AdSDK / PaySDK / ARSDK ──────── (独立)
```

ABTestSDK 同时依赖 AnalyticsSDK 和 ConfigSDK（菱形依赖），后续任务编排时能体现拓扑排序的价值。

### Mock 实现方式

每个 SDK 是一个 class，暴露 `static func setup()` 方法，内部用 `Thread.sleep` 模拟耗时（从范围内随机取值）。当前阶段全部串行调用，后续任务编排时改为按依赖关系并行。

### 当前阶段串行调用顺序

在 AppDelegate.didFinishLaunchingWithOptions 中按梯队顺序串行调用：

```
CrashSDK → DeviceIDSDK → ConfigSDK →
AnalyticsSDK → PushSDK → ABTestSDK → ShareSDK →
MapSDK → AdSDK → PaySDK → ARSDK
```

全串行耗时预估：1020-1700ms，优化空间明显。

## 控制台报告格式

启动完成后一次性输出：

```
╔══════════════════════════════════════════════════╗
║            🚀 Launch Metrics Report              ║
╠══════════════════════════════════════════════════╣
║ Device: iPhone15,2 | iOS 18.0 | WiFi | 6GB RAM  ║
║ App: 1.0.0 | First Launch: false                 ║
╠══════════════════════════════════════════════════╣
║ Phase Breakdown:                                 ║
║   pre-main            :  120ms                   ║
║   main→didFinish      :    2ms                   ║
║   SDK init            :  980ms                   ║
║   didFinish→firstFrame:  150ms                   ║
║   ─────────────────────────────                  ║
║   Total               : 1252ms                   ║
╠══════════════════════════════════════════════════╣
║ SDK Details:                                     ║
║   CrashSDK            :   45ms                   ║
║   DeviceIDSDK         :   67ms                   ║
║   ConfigSDK           :   82ms                   ║
║   AnalyticsSDK        :  130ms                   ║
║   PushSDK             :   78ms                   ║
║   ABTestSDK           :  156ms                   ║
║   ShareSDK            :   95ms                   ║
║   MapSDK              :  180ms                   ║
║   AdSDK               :  140ms                   ║
║   PaySDK              :   55ms                   ║
║   ARSDK               :  312ms                   ║
╚══════════════════════════════════════════════════╝
```

## 与后续任务编排的衔接

度量体系先于任务编排建立，后续衔接方式：

1. **度量打点保留**：阶段级打点（pre-main、firstFrame）始终由 LaunchMetrics 管理
2. **SDK 级打点迁移**：任务编排框架建好后，框架自动在每个任务前后调用 `LaunchMetrics.mark`，替代 AppDelegate 里的手动 `trackSDK`
3. **对比验证**：编排前后用同一套度量报告对比，量化优化效果
