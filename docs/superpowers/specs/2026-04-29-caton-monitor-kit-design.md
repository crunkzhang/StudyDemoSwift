# CatonMonitorKit — 卡顿检测设计方案

## 概述

为 WeChatSwift 项目构建企业级卡顿检测框架 `CatonMonitorKit`，采用管道式架构，覆盖 RunLoop 监控、帧率检测、Watchdog 死锁检测三种手段。Debug 模式下提供实时浮窗诊断，Release 模式下低开销采样上报。

## 设计决策

| 维度 | 决策 | 理由 |
|------|------|------|
| 场景 | Debug 诊断 + Release 线上监控 | 企业级项目需要两者兼顾 |
| 检测手段 | RunLoop + FPS + Watchdog | 覆盖短卡顿、掉帧、死锁三种场景 |
| 堆栈采集 | `thread_get_state` + FP 链回溯 | 子线程获取主线程寄存器状态，沿 FP 链回溯栈帧地址，Release 下开销极低 |
| 上报 | 本地持久化 + Reporter 协议注入 | 不绑定具体后端，业务方自行对接 |
| 架构位置 | Foundation 层 | 零业务依赖，可跨项目复用 |
| 开发体验 | 控制台日志 + Debug 浮窗 | FPS 实时显示 + 卡顿闪红 |
| 架构风格 | 管道式（Pipeline） | 各环节职责单一、可独立测试、可按需组合 |

## 范围

- 只做卡顿检测，不涉及启动调度（LaunchScheduler）或埋点体系
- 与现有 `LaunchMetrics`、`LaunchScheduler` 独立运行，互不依赖

## 模块结构

```
Modules/Foundation/CatonMonitorKit/
├── Core/
│   ├── CatonMonitor.swift          ← 协调者，管理管道生命周期
│   ├── CatonConfig.swift           ← 配置（阈值、采样率、开关）
│   └── CatonEvent.swift            ← 统一的卡顿事件数据模型
├── Detectors/
│   ├── CatonDetectable.swift       ← 检测器协议
│   ├── RunLoopDetector.swift       ← RunLoop 监控
│   ├── FPSDetector.swift           ← 帧率检测（CADisplayLink）
│   └── WatchdogDetector.swift      ← 独立线程死锁检测
├── StackCapture/
│   └── StackCapture.swift          ← thread_get_state + FP 链回溯主线程堆栈
├── PageTracker/
│   └── PageTracker.swift           ← swizzle viewDidAppear 维护页面栈，提供当前页面类名
├── Storage/
│   ├── CatonStorable.swift         ← 存储协议
│   └── CatonDiskStore.swift        ← JSON 文件本地持久化
├── Reporter/
│   ├── CatonReportable.swift       ← 上报协议（业务方注入）
│   └── ReportStrategy.swift        ← 采样率、聚合去重、批量攒发
└── DebugUI/
    └── CatonOverlayWindow.swift    ← Debug 浮窗（FPS + 卡顿闪红）
```

## 数据流

```
RunLoopDetector ─┐
FPSDetector ─────┤→ CatonEvent → StackCapture → CatonDiskStore → Reporter
WatchdogDetector ┘
```

## 核心数据模型

### CatonEvent

```swift
struct CatonEvent {
    let id: UUID
    let type: CatonType           // .runLoop / .fps / .watchdog
    let duration: TimeInterval    // 卡顿持续时长（ms）
    let stackTrace: [String]      // 堆栈帧地址（Release）或符号化堆栈（Debug）
    let timestamp: Date
    let threadInfo: ThreadInfo    // 主线程 QoS、CPU 占用
    let page: String?             // 当前页面（swizzle viewDidAppear 维护的页面栈栈顶类名）
    let isAppInBackground: Bool
}

enum CatonType: String, Codable {
    case runLoop    // 主线程 RunLoop 超时
    case fps        // 连续掉帧
    case watchdog   // 主线程无响应（死锁级）
}

struct ThreadInfo {
    let cpuUsage: Double          // 主线程 CPU 时间占比（thread_info THREAD_BASIC_INFO）
    let threadCount: Int          // 当前进程线程数
}
```

### CatonConfig

```swift
struct CatonConfig {
    // 检测器开关
    var enableRunLoop: Bool = true
    var enableFPS: Bool = true
    var enableWatchdog: Bool = true

    // 阈值
    var runLoopThreshold: TimeInterval = 0.1    // RunLoop 超过 100ms 判定卡顿
    var fpsDropThreshold: Int = 10              // FPS 连续低于该值触发
    var watchdogTimeout: TimeInterval = 2.0     // 主线程无响应 2s 判定死锁

    // 上报策略
    var sampleRate: Double = 1.0               // 采样率，Release 建议 0.1
    var maxStoredEvents: Int = 200             // 本地最多缓存条数
    var reportBatchSize: Int = 20              // 批量上报条数

    // Debug
    var showOverlay: Bool                      // 是否显示浮窗

    static var `default`: CatonConfig {
        #if DEBUG
        CatonConfig(showOverlay: true)
        #else
        CatonConfig(sampleRate: 0.1, showOverlay: false)
        #endif
    }
}
```

## 检测器设计

### CatonDetectable 协议

```swift
protocol CatonDetectable: AnyObject {
    var onCatonDetected: ((CatonEvent) -> Void)? { get set }
    func start()
    func stop()
}
```

### RunLoopDetector

子线程用信号量等待主线程 RunLoop 状态变化���超时即判定卡顿。

- 注册 RunLoop Observer 监听 `kCFRunLoopBeforeSources` 和 `kCFRunLoopAfterWaiting`
- 每���状态变化 signal 信号量，同时记录当前 activity 状态
- 子线程 `wait(timeout: runLoopThreshold)`，超时 �� 采集堆栈 → 生成 `CatonEvent(.runLoop)`
- **关键判定条件**：只有当前 activity 处于 `beforeSources`（正在处理事件源）或 `afterWaiting`（刚被唤醒正在处理）时超时才判定为卡顿。`beforeWaiting` 表示主线程即将进入空闲等待，超时是正常的，不应上报
- 卡顿判定在子线程完成，不额外占用主线程资源

### FPSDetector

`CADisplayLink` 回调计算帧间隔。

- 挂在主线程 RunLoop 的 `common` mode 下，滚动时也能检测
- 每秒计算一次 FPS，连续低于 `fpsDropThreshold` 触发事件
- 通过闭包 `onFPSUpdate: ((Int) -> Void)?` 广播实时 FPS 值给浮窗

### WatchdogDetector

独立高优先级线程定时检查主线程是否存活，超时即判定死锁。

- 主线程通过 `CFRunLoopTimerRef`（添加到 `commonModes`）定时更新一个时间戳，确保滚动（tracking mode）期间也能正常更新
- 子线程每隔 `watchdogTimeout` 检查时间戳是否过期，过期 → 采集堆栈 → 生成 `CatonEvent(.watchdog)`
- 不使用 `DispatchQueue.main.async`：GCD main queue 在 default mode 下执行，滚动时 block 会延迟，导致误报
- 线程优先级 `QOS_CLASS_USER_INTERACTIVE`，避免被调度饿死
- 与 RunLoopDetector 互补：RunLoop 捕获 100ms~2s，Watchdog 捕获 >2s
- 去重：同一时段 RunLoopDetector 已上报的事件，Watchdog 不重复上报

## 堆栈采集

### StackCapture

采集流程：
1. 检测器判定卡顿 → 调用 `StackCapture.capture()`（已在子线程）
2. 通过 `thread_get_state` 获取主线程 PC/FP 寄存器
3. 沿 FP 链回溯主线程栈帧地址（最多 128 帧）

符号化策略：
- **Debug**：`dladdr()` 本地符号化 → 可读的 "类名.方法名 + 偏移"
- **Release**：保留原始地址 + imageUUID + slideOffset → 服务端用 dSYM 符号化

关键约束：
- 采集在子线程完成，不阻塞主线程
- 不使用 `backtrace()`——该函数只能采集调用线程自身的堆栈，无法跨线程采集主线程
- `thread_get_state` 是跨线程采集的正确方式，通过 Mach thread port 获取目标线程寄存器快照
- 采集耗时控制在 1ms 以内

## 本地存储

### CatonDiskStore

```
目录：Library/Caches/CatonMonitorKit/
格式：每个事件一个 JSON 文件，文件名为 {uuid}.json
```

写入流程：
1. `CatonEvent` → Codable → JSON Data
2. 写入专用串行队列（不阻塞检测线程）
3. 写入后检查文件数，超过 `maxStoredEvents` 删除最旧的

读取流程：
1. Reporter 批量读取 → 上报成功 → 删除对应文件
2. App 启动时检查未上报的历史事件，延迟上报

选择 JSON 文件而非 SQLite：事件量不大（日均几十到几百条），文件粒度操作简单直接，无外部依赖。

## 上报策略

### CatonReportable 协议

```swift
protocol CatonReportable {
    func report(events: [CatonEvent], completion: @escaping (Bool) -> Void)
}
```

业务方注入具体实现：

```swift
CatonMonitor.shared.reporter = SentryCatonReporter()
```

### ReportStrategy — 三层过滤

1. **采样过滤**：按 `sampleRate` 概率丢弃，对 deviceID hash 取模保证同设备行为一致
2. **聚合去重**：同一页面 + 同一堆栈 top 3 帧视为同类卡顿，聚合为一条（附 count + firstSeen/lastSeen）
3. **批量攒发**：队列 ≥ `reportBatchSize` / App 进入后台 / 距上次上报超过 5 分钟，满足任一即触发。上报失败保留本地，下次启动重试

## Debug 浮窗

### CatonOverlayWindow

```
视觉设计：
  ┌──────────┐
  │ FPS: 60  │  ← 正常绿色，<45 黄色，<30 红色
  │ Caton: 0 │  ← 累计卡顿次数，发生卡顿时整个浮窗闪红 0.3s
  └──────────┘
```

实现要点：
- 独立 `UIWindow`，`windowLevel = .statusBar + 1`
- 默认右上角，可拖拽
- 仅 `#if DEBUG` 编译条件下可用
- 单击展开详情面板，显示最近 5 条卡顿的页面和耗时
- 长按将最近卡顿堆栈复制到剪贴板

## CatonMonitor 协调者

### 外部 API

```swift
final class CatonMonitor {
    static let shared = CatonMonitor()

    var reporter: CatonReportable?

    func start(config: CatonConfig = .default)
    func stop()
    func pauseDetection()            // 已知耗时操作时临时暂停
    func resumeDetection()
}
```

### 启动流程

```
CatonMonitor.start(config:)
  ├→ 根据 config 开关创建对应 Detector
  │   ├→ RunLoopDetector.start()
  │   ├→ FPSDetector.start()
  │   └→ WatchdogDetector.start()
  ├→ 为每个 Detector 设置 onCatonDetected → handleEvent()
  ├→ 初始化 CatonDiskStore
  ├→ 检查本地未上报的历史事件，延迟 5s 批量上报
  └→ if config.showOverlay → 启动 CatonOverlayWindow
```

### 事件管道 handleEvent()

```
Detector 回调触发
  ├→ 1. StackCapture.capture() 采集堆栈
  ├→ 2. 填充 page（通过 swizzle viewDidAppear 维护的页面栈获取当前页面类名，RN 页面通过 RNBaseViewController 自动覆盖）
  ├→ 3. 填充 threadInfo（thread_info 获取 CPU 时间占比、线程数）
  ├→ 4. 去重检查（与最近事件比较 top 3 帧）
  ├→ 5. CatonDiskStore.save(event)
  ├→ 6. ReportStrategy.enqueue(event)
  ├→ 7. Debug 下控制台输出 + 通知浮窗闪红
  └→ 8. 广播通知（NotificationCenter）供外部监听
```

### 与现有模块的关系

`CatonMonitorKit` 位于 Foundation 层，与 `LaunchMetrics`（App 层）和 `LaunchScheduler`（App 层）完全独立。业务方在 `AppDelegate` 中一行启动：

```swift
// AppDelegate.swift
func application(_ application: UIApplication, didFinishLaunchingWithOptions ...) {
    CatonMonitor.shared.start()   // 独立于 LaunchScheduler
}
```
