# RN Bundle 远程热更新 - 企业级方案设计

## 目标

将现有的最小闭环 RN bundle 远程加载能力，升级为具备灰度发布、白名单、自动回滚、监控埋点等完整能力的企业级热更新方案。纯学习 Demo，不上线，但模拟真实企业架构。

## 架构概述

采用"胖配置文件"方案：OSS 上放一个 `update-config.json` 包含所有策略，客户端拉取后自行决策。预留接口设计，后续可替换为服务端 API。

全量下载 bundle（不做差量更新），bundle 体积在 1-5MB 范围内。

---

## 1. OSS 文件结构

```
oss://cz-rn-bundle/
├── update-config.json
└── bundles/
    ├── v1/main.jsbundle
    ├── v2/main.jsbundle
    └── v3/main.jsbundle
```

### update-config.json

```json
{
  "latestVersion": 3,
  "minAppVersion": "1.0.0",
  "bundles": {
    "3": {
      "url": "https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com/bundles/v3/main.jsbundle",
      "md5": "a1b2c3d4e5f6...",
      "size": 1307885,
      "releaseNotes": "修复联系人页面白屏",
      "applyMode": "nextLaunch",
      "grayscale": {
        "percentage": 30,
        "whitelist": ["DEVICE_ID_001", "DEVICE_ID_002"],
        "minAppVersion": "1.2.0"
      }
    },
    "2": {
      "url": "https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com/bundles/v2/main.jsbundle",
      "md5": "f6e5d4c3b2a1...",
      "size": 1290000,
      "releaseNotes": "新增发现页",
      "applyMode": "nextLaunch",
      "grayscale": {
        "percentage": 100,
        "whitelist": [],
        "minAppVersion": "1.0.0"
      }
    }
  }
}
```

### 字段说明

| 字段 | 含义 |
|------|------|
| `latestVersion` | 当前最新版本号 |
| `minAppVersion` | 全局最低 app 版本要求 |
| `bundles[N].url` | bundle 下载地址 |
| `bundles[N].md5` | 完整性校验（下载后校验） |
| `bundles[N].size` | 文件大小（字节） |
| `bundles[N].applyMode` | `"nextLaunch"` 下次启动生效 / `"immediate"` 提示用户立即生效 |
| `grayscale.percentage` | 灰度比例 0-100 |
| `grayscale.whitelist` | 白名单设备 ID 数组，命中则无视灰度比例直接推送 |
| `grayscale.minAppVersion` | 该版本 bundle 要求的最低 app 版本 |

---

## 2. 客户端架构

```
┌─────────────────────────────────────────────────┐
│                  AppDelegate                     │
│         启动时调用 BundleManager.start()           │
└──────────────────────┬──────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────┐
│              RNBundleManager                     │
│  对外唯一入口，协调各模块，提供 bundlePath            │
│  - configure(remoteURL:appVersion:)              │
│  - start() 启动检查 + 注册前后台/定时触发            │
│  - checkUpdate() 单次检查                         │
│  - bundlePath: URL? 供 RNFactoryManager 读取       │
│  - markHealthy() RN 加载成功后调用                  │
└──┬──────────┬──────────┬──────────┬─────────────┘
   │          │          │          │
   ▼          ▼          ▼          ▼
┌──────────┐┌──────────┐┌──────────┐┌──────────────┐
│  Config  ││ Version  ││  Down-   ││   Monitor    │
│  Fetcher ││ Resolver ││  loader  ││   Reporter   │
└──────────┘└──────────┘└──────────┘└──────────────┘
```

### 模块职责

| 模块 | 文件 | 职责 |
|------|------|------|
| `RNBundleManager` | `RNBundleManager.swift` | 对外唯一入口，协调所有模块，管理更新触发时机（启动/前台/轮询），防并发去重 |
| `BundleConfigFetcher` | `BundleConfigFetcher.swift` | 拉取 `update-config.json`，解析为 Swift 模型 |
| `BundleVersionResolver` | `BundleVersionResolver.swift` | 输入配置 + 设备信息（deviceId/appVersion），输出"该更新到哪个版本"或"不更新" |
| `BundleDownloader` | `BundleDownloader.swift` | 下载 bundle 到临时文件，MD5 校验，原子性写入 Documents |
| `BundleMetadata` | `BundleMetadata.swift` | metadata.json 的读写，本地版本状态管理 |
| `BundleMonitorReporter` | `BundleMonitorReporter.swift` | 事件定义、Reporter 协议、ConsoleBundleReporter 默认实现 |
| `BundleModels` | `BundleModels.swift` | UpdateConfig / BundleInfo / GrayscaleConfig 等 Codable 数据模型 |

---

## 3. 策略决策逻辑

`BundleStrategyResolver` 的判断流程：

1. 拉取 config，获取 `latestVersion` 对应的 bundle 配置
2. 当前 app 版本 < `grayscale.minAppVersion` → 跳过该版本
3. 设备 ID 在 `grayscale.whitelist` 中 → 直接命中，推送该版本
4. 未在白名单 → `hash(deviceId) % 100 < grayscale.percentage` → 命中灰度
5. 命中 → 返回该版本的下载信息
6. 未命中最新版 → 从 bundles 中倒序查找最大的已全量发布（percentage=100）且满足 minAppVersion 的版本
7. 找到且 != 本地当前版本 → 返回该版本（支持降级回滚）
8. 未找到 → 返回"不更新"

---

## 4. 更新触发时机

| 触发方式 | 实现 |
|---------|------|
| 启动时 | `AppDelegate.didFinishLaunching` 调用 `BundleManager.start()` |
| 前后台切换 | `SceneDelegate.sceneWillEnterForeground` 调用 `BundleManager.checkUpdate()` |
| 定时轮询 | 前台期间 Timer 每 30 分钟触发一次（可配置），进入后台暂停 |
| 去重 | `BundleManager` 内部用 flag 防止并发检查，`metadata.lastCheckTime` 防止短时间重复请求（60 秒内不重复） |

---

## 5. 更新生效方式

### nextLaunch（下次启动生效）

下载完成 → 写入 `current/main.jsbundle` → 更新 metadata → 下次启动 `bundlePath` 返回新文件

### immediate（提示立即生效）

下载完成 → 写入 `current/main.jsbundle` → 更新 metadata → 发送 `Notification.Name("RNBundleDidUpdate")` → UI 层弹窗提示 → 用户确认 → 调用 `RCTBridge.reload()` 重载 RN

---

## 6. 本地存储

### Documents 目录结构

```
Documents/RNBundle/
├── current/
│   └── main.jsbundle          ← 当前使用的 bundle
├── downloading/
│   └── main.jsbundle.tmp      ← 下载中的临时文件
└── metadata.json              ← 本地版本元数据
```

### metadata.json

```json
{
  "currentVersion": 3,
  "lastHealthyVersion": 2,
  "md5": "a1b2c3d4e5f6...",
  "consecutiveFailures": 0,
  "lastCheckTime": 1750000000,
  "deviceId": "UUID-xxxx-xxxx"
}
```

| 字段 | 用途 |
|------|------|
| `currentVersion` | 当前已下载的 bundle 版本，0 表示使用内置 bundle |
| `lastHealthyVersion` | 最近一次 RN 加载成功的版本号 |
| `consecutiveFailures` | 连续启动未标记健康的次数 |
| `lastCheckTime` | 上次检查更新的时间戳（秒），用于去重 |
| `deviceId` | 首次启动时生成的 UUID，持久化存储，用于灰度取模和白名单匹配 |

### 下载写入流程

1. 下载到 `downloading/main.jsbundle.tmp`
2. 计算下载文件的 MD5
3. 与 config 中的 `md5` 比对
4. 匹配 → 将 `downloading/main.jsbundle.tmp` rename 到 `current/main.jsbundle`，更新 `metadata.json`
5. 不匹配 → 删除临时文件，上报 `download_fail` 事件

---

## 7. 自动回滚

### 设计思路

无法直接 catch RN 崩溃，所以用反证法：每次启动先假设会失败（计数器 +1），RN 加载成功后再把计数器清零。如果连续 3 次启动计数器都没被清零，说明 bundle 有问题。

### 逐次启动时序

**正常情况（bundle 没问题）：**

```
app 启动 → consecutiveFailures 从 0 变 1，写 metadata
    → 加载 current/main.jsbundle
    → RN 渲染成功 → markHealthy()
    → consecutiveFailures = 0，lastHealthyVersion = currentVersion
```

**异常情况（bundle 有问题，连续崩溃）：**

```
第 1 次启动 → consecutiveFailures: 0→1 → RN 崩溃 → markHealthy() 未调用 → 用户杀 app
第 2 次启动 → consecutiveFailures: 1→2 → 同样崩溃
第 3 次启动 → consecutiveFailures: 2→3 → 触发回滚！
    → 删除 current/main.jsbundle
    → currentVersion = 0
    → 上报 rollback 事件
    → 本次启动加载内置 bundle
```

### 为什么回退到内置 bundle 而不是 lastHealthyVersion

`current/` 目录只保留一个 bundle，新版本下载时已经覆盖了旧版本。回滚时旧版本不在本地了，重新下载需要网络，不能保证可用。内置 bundle 打包在 app 里，永远存在，是唯一 100% 可靠的兜底。

`lastHealthyVersion` 的作用是监控上报（让你知道"从哪个版本回退的"），不用于恢复。

### markHealthy() 触发方式

监听 `NSNotification.Name.RCTJavaScriptDidLoad`（React Native 内置通知），收到后调用 `BundleManager.markHealthy()`。这比从 JS 侧回调更可靠，因为不依赖 JS 代码本身是否正常执行。

### 远程回滚

修改 OSS 上 `update-config.json` 的 `latestVersion` 降低版本号。客户端下次检查时，`StrategyResolver` 算出的目标版本 < 本地版本，走正常的下载-校验-写入流程完成降级。与升级共用同一条代码路径，版本比较用 `!=` 而非 `>` 以同时覆盖升级和降级。

---

## 8. 监控埋点

### 事件定义

| 事件 | 触发时机 | 携带数据 |
|------|---------|---------|
| `check_update` | 请求 config | deviceId, currentVersion, appVersion |
| `update_available` | 发现可更新版本 | deviceId, fromVersion, toVersion, grayscaleHit(whitelist/percentage/none) |
| `download_start` | 开始下载 | deviceId, targetVersion |
| `download_success` | 下载 + MD5 通过 | deviceId, targetVersion, fileSize, durationMs |
| `download_fail` | 下载失败或 MD5 不匹配 | deviceId, targetVersion, errorType(network/md5_mismatch), errorMsg |
| `load_success` | RN Bridge 加载成功 | deviceId, version, source(downloaded/builtin), loadTimeMs |
| `load_fail` | RN Bridge 加载失败 | deviceId, version, source, errorMsg |
| `rollback` | 触发自动回滚 | deviceId, fromVersion, toVersion(0=builtin), consecutiveFailures |
| `apply_immediate` | 用户确认立即生效 | deviceId, version |

### Reporter 协议

```swift
public protocol BundleEventReporter {
    func report(_ event: BundleEvent)
}
```

第一阶段提供 `ConsoleBundleReporter`，所有事件 print 到控制台：

```
[BundleMonitor] load_success | v3 | source=downloaded | loadTime=127ms
[BundleMonitor] rollback | v3->builtin | failures=3
```

第二阶段可实现 `RemoteBundleReporter`，通过 protocol 注入替换，不改内部逻辑：

```swift
// 第一阶段
BundleManager.shared.reporter = ConsoleBundleReporter()

// 第二阶段
BundleManager.shared.reporter = RemoteBundleReporter(endpoint: "https://xxx")
```

---

## 9. 文件结构

所有代码在 `WeChatRN` pod 内（glob `**/*.swift` 自动索引）：

```
Modules/WeChatKit/WeChatRN/
├── RNBundleUpdate/
│   ├── RNBundleManager.swift
│   ├── BundleConfigFetcher.swift
│   ├── BundleVersionResolver.swift
│   ├── BundleDownloader.swift
│   ├── BundleMetadata.swift
│   ├── BundleMonitorReporter.swift
│   └── BundleModels.swift
├── RNFactoryManager.swift              ← 改动：bundleURL() 读取 BundleManager.bundlePath
├── RNBundleUpdater.swift               ← 删除（被新模块替代）
└── ...existing files...
```

### 对外接口

**AppDelegate.swift：**

```swift
RNBundleManager.shared.configure(
    remoteURL: "https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com",
    appVersion: "1.0.0"
)
RNBundleManager.shared.start()
```

**SceneDelegate.swift：**

```swift
func sceneWillEnterForeground(_ scene: UIScene) {
    RNBundleManager.shared.checkUpdate()
}
```

**RNFactoryManager.swift（Release 模式）：**

```swift
return RNBundleManager.shared.bundlePath
    ?? Bundle.main.url(forResource: "main", withExtension: "jsbundle")
```

### 删除的文件

- `RNBundleUpdater.swift` — 被 `RNBundleUpdate/` 目录下的模块完全替代

---

## 10. 与现有代码的关系

| 现有文件 | 改动 |
|---------|------|
| `AppDelegate.swift` | 替换 `RNBundleUpdater` 调用为 `RNBundleManager.configure() + start()` |
| `SceneDelegate.swift` | 添加 `sceneWillEnterForeground` 调用 `checkUpdate()` |
| `RNFactoryManager.swift` | `bundleURL()` 的 Release 分支改为读取 `RNBundleManager.shared.bundlePath` |
| `RNBundleUpdater.swift` | 删除 |
| `WeChatSwift.xcodeproj/project.pbxproj` | 无需改动（pod glob 自动索引新文件） |

---

## 11. OSS 操作流程（发布新版本）

1. 本地打包：`npx react-native bundle --platform ios --dev false --entry-file index.js --bundle-output bundle/ios/main.jsbundle`
2. 计算 MD5：`md5 bundle/ios/main.jsbundle`
3. 上传到 OSS：`bundles/vN/main.jsbundle`
4. 修改 `update-config.json`：添加新版本条目，设置灰度比例
5. 上传新的 `update-config.json`

回滚操作：修改 `update-config.json` 的 `latestVersion` 降低版本号即可。
