# 游戏模块(GameModule)设计文档

**日期**:2026-05-30
**范围**:Discover 入口"游戏"项重做为原生路由 → H5 游戏大厅 + WebView 小游戏,
游戏 H5 资源走 OSS 远程下发支持自动更新 / 灰度 / 回滚。
**目标**:复刻微信"游戏中心"形态(H5 大厅 + WebView 游戏),作为简历"客户端动态化方案 + AI Coding 实战"的示例。

---

## 一、背景与目标

### 现状

`DiscoverViewController` 里"游戏"入口路由是 `wechat://rn?page=gameCenter` → RN 渲染。WeChatRN 的 chat 页面已经改为原生(IM 2.0 重构),游戏入口现在依然走 RN,跟整体"原生为主"的方向不一致。

### 目标

1. **Discover 游戏入口改为原生路由** → 进入 H5 游戏大厅
2. **大厅 H5** 内置在 GameModule pod 内,展示游戏卡片网格(从 manifest 渲染)
3. **具体游戏 H5** 走 OSS 远程下载 + SHA256 校验 + 解压,WebView 加载本地 file://
4. **GameBundleManager 自动更新** 支持新游戏自动上线 / 升级 / 下架 / 灰度 / 回滚,**不发新 app 版本**
5. **3 款经典游戏 ship**:2048 / 俄罗斯方块 / 记忆翻牌(全 AI 生成,演示 AI Coding 提效)

### 非目标

- AI 五子棋(Phase 1 跳过,后续单独迭代;真要做需引入 Bridge 通道转发 Claude API)
- JS Bridge 框架(纯 web 游戏自闭环,大厅 → 游戏走 URL scheme 拦截,无 Bridge)
- 大厅 H5 走 OSS 热更新(Phase 1 内置,架构预留扩展点,Phase 2 可加)
- 游戏内 IM 分享 / 排行榜 / 多人对战(超出 Phase 范围)

### 简历卖点

- **混合开发**:WKWebView + URL scheme + 远程资产管理,与 RN 同套思路但场景不同(H5 vs RN bundle)
- **客户端动态化**:GameBundleManager 与 RNBundleManager 同思路双场景落地,讲"统一资产管理"有抓手
- **AI Coding 实战**:3 款游戏全部 Claude/Codex 生成,讲"AI 提效产出 H5 应用"有具体产物
- **灰度 / 回滚**:manifest 驱动 + SHA256 校验 + 多版本回退,演示"客户端可靠动态化"

---

## 二、模块划分

```
HelloRN/                                      ← 顶层(已有)
├── WeChatSwift/                              ← iOS 工程
│   └── Modules/Business/
│       └── GameModule/                      ← 新建 Pod
├── WeChatRN/                                 ← 已有 RN 工程
├── WeChatKotlin/                             ← 已有 Android 工程
└── WeChatGames/                              ← 新建,游戏前端源码工程
    ├── 2048/, tetris/, memory/
    └── scripts/build.sh, upload.sh
```

**依赖方向**:GameModule → WeChatRouter / WeChatUI / ExtensionKit / SnapKit;**不依赖** WCIMSDK / ChatModule。

### Modules/Business/GameModule/ 目录结构

```
Modules/Business/GameModule/
├── GameModule.podspec
├── GameModule.swift                          # registerRoutes() 入口
│
├── Hall/                                     # H5 大厅容器
│   └── VC/GameHallViewController.swift      # WKWebView 加载内置 hall.html
│                                             # + 注入 GAME_MANIFEST
│                                             # + URL scheme 拦截
│
├── Runner/                                   # 游戏运行器
│   ├── VC/GameRunnerViewController.swift    # WKWebView 加载下载好的 file://
│   └── GameLoadState.swift                  # idle / loading / downloading / ready / failed
│
├── BundleManager/                            # 远程动态化
│   ├── GameBundleManager.swift              # 协调单例(start / refreshManifest / bundleURL)
│   ├── GameManifest.swift                   # 远程数据 model(Codable)+ 缓存读写
│   ├── GameBundleStorage.swift              # 本地 zip 存储 / 解压 / 版本路径管理
│   └── GameDownloader.swift                 # URLSession.download + SHA256 校验
│
└── Resources/                                # 大厅 H5 内置资源(随 app 发版)
    └── Hall/
        ├── hall.html
        ├── hall.css
        └── hall.js
```

### HelloRN/WeChatGames/ 目录结构(独立前端工程)

```
HelloRN/WeChatGames/
├── README.md                                # 维护说明 + build/upload 流程
├── 2048/
│   ├── index.html
│   ├── main.js
│   ├── style.css
│   ├── icon.png
│   └── README.md
├── tetris/
│   └── ...
├── memory/
│   └── ...
└── scripts/
    ├── build.sh                             # ./build.sh 2048 1.1 → dist/2048-v1.1.zip + SHA256
    └── upload.sh                            # aliyun-cli 上传 OSS + 更 manifest.json
```

---

## 三、架构总览

```
              ┌─────────────────────────────────────────────────┐
              │  Discover 页 → "游戏" → Routes.game             │
              └────────────────────────┬────────────────────────┘
                                       │ Router.push
                                       ▼
              ┌─────────────────────────────────────────────────┐
              │  GameHallViewController (WKWebView + hall.html) │
              │  ↑ 注入 GAME_MANIFEST = {...}                   │
              │  ↑ 拦截 wechat://game/run?id=X URL scheme       │
              └────────────────────────┬────────────────────────┘
                                       │ Router.push Routes.gameRun?id=X
                                       ▼
              ┌─────────────────────────────────────────────────┐
              │  GameRunnerViewController (WKWebView)           │
              │  ├─ 状态:loading → downloading → ready          │
              │  └─ WebView.loadFileURL(本地 index.html)        │
              └────────────────────────┬────────────────────────┘
                                       │ bundleURL(for: gameId)
                                       ▼
              ┌─────────────────────────────────────────────────┐
              │  GameBundleManager (单例)                       │
              │  ├─ currentManifest:本地缓存                   │
              │  ├─ refreshManifest():远程拉 → 写本地缓存       │
              │  └─ bundleURL(for:) async:                      │
              │      ① 命中本地版本 → file URL                 │
              │      ② 未命中 → downloader + SHA256 + unzip   │
              └─────────────────────────────────────────────────┘
                          ↑                          ↑
                          │                          │
          ┌───────────────┴───────┐      ┌──────────┴────────────┐
          │  OSS manifest.json    │      │  OSS games/*.zip      │
          │  (远程游戏清单)        │      │  (各游戏 H5 资源包)    │
          └───────────────────────┘      └───────────────────────┘
```

### 自动更新触发时机

| 时机 | 触发动作 | 用户感知 |
|---|---|---|
| **App 启动** | GameBundleManager.start() 后台拉 manifest | 无 |
| **大厅 viewDidAppear** | refreshManifest() 拉一次,WebView reload 显示新列表 | 新游戏自动出现 / 下架的消失 |
| **进入具体游戏** | 比对本地版本 vs manifest → 过期则下载 | 短暂"加载中",新版替换老版 |
| **30 分钟定时轮询** | 后台静默 refreshManifest | 无 |

---

## 四、数据流(收 / 进 / 玩 / 退)

### 4.1 启动 + 进大厅
```
App 启动
  → AppDelegate / LaunchScheduler 触发
    GameBundleManager.shared.start(remoteURL: "https://.../games/manifest.json")
       └─ 后台拉 manifest → 写 Documents/Games/manifest.json
       └─ 启动 30min 定时轮询

用户:Discover → 游戏(点击)
  → Router.push("wechat://game/hall")
  → GameHallViewController.viewDidLoad
    ├─ 注入 WKUserScript:window.GAME_MANIFEST = { games: [...] }
    └─ webView.loadFileURL(Bundle/hall.html)

hall.js 启动:
  ├─ 读 window.GAME_MANIFEST.games 渲染卡片
  └─ 卡片 onclick → location.href = "wechat://game/run?id=2048"
```

### 4.2 大厅刷新

```
GameHallVC.viewDidAppear
  → Task { await GameBundleManager.shared.refreshManifest() }
  → 拉到新 manifest → 写本地缓存 → 通知 VC
  → VC 重新注入新 manifest + webView.reload()
  → 用户看到列表更新
```

### 4.3 进游戏

```
WKNavigationDelegate.decidePolicyForNavigationAction:
  url.scheme == "wechat"
  → decisionHandler(.cancel)
  → Router.shared.push("wechat://game/run?id=2048")

GameRunnerViewController.init(gameId: "2048")
  viewDidLoad:
    state = .loading
    Task {
      let localURL = await GameBundleManager.shared.bundleURL(for: "2048")
      if let url = localURL {
        state = .ready
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
      } else {
        state = .failed
      }
    }

bundleURL(for:) 内部:
  ├─ manifest 中找 game = "2048"
  ├─ 本地有该 version → 返回 file URL
  └─ 未命中 → downloader.download(url, sha256) → unzip 到 Documents/Games/2048/{version}/
      ├─ SHA256 不匹配 → 删 → 返回 nil
      └─ 解压成功 → 返回 file URL
```

### 4.4 退出 / 后台

- VC pop → WebView 自动释放(游戏 H5 自负)
- 本地缓存保留(下次秒开)
- 可选:每个游戏只保留最近 2 个 version,老的超 N 天自动清

---

## 五、GameBundleManager 设计

### 接口

```swift
public final class GameBundleManager {
    public static let shared = GameBundleManager()

    /// 当前 manifest 缓存(供大厅渲染列表 + 注入到 H5)
    public private(set) var currentManifest: GameManifest?

    /// AppDelegate / LaunchScheduler 调,启动后台 manifest 拉取 + 30min 轮询
    public func start(remoteURL: String)

    /// 强制刷新 manifest(大厅 viewDidAppear 调用)
    public func refreshManifest() async

    /// 拿某个游戏的本地 index.html 路径
    /// 未命中或版本过期 → 触发下载 + SHA256 + 解压 → 返回新路径
    /// 失败返回 nil
    public func bundleURL(for gameId: String) async -> URL?
}
```

### GameManifest model

```swift
public struct GameManifest: Codable {
    public let manifestVersion: Int
    public let updatedAt: String
    public let games: [GameEntry]
}

public struct GameEntry: Codable {
    public let id: String              // "2048"
    public let title: String           // "2048"
    public let icon: String            // "https://..."
    public let version: String         // "1.0" / "1.1"
    public let url: String             // zip 下载 URL
    public let sha256: String          // 校验
    public let size: Int               // 字节数(UI 显示下载进度用)
    public let grayscale: Grayscale?   // 灰度策略(Phase 3 启用)
}

public struct Grayscale: Codable {
    public let percentage: Int         // 0-100
    public let whitelist: [String]     // deviceId 白名单
}
```

### 本地路径约定

```
Documents/Games/
├── manifest.json                     ← 最近一次远程 manifest 缓存
├── 2048/
│   ├── 1.0/                          ← v1.0 解压后目录
│   │   ├── index.html
│   │   ├── main.js
│   │   └── style.css
│   └── 1.1/                          ← v1.1 升级后,旧版保留一段时间用于回滚
└── tetris/1.0/, memory/1.0/
```

### 下载流程

```
GameDownloader.download(url, expectedSHA256, destination) async throws:
  1. URLSession.download(url) → tmpFile
  2. shasum256(tmpFile)
  3. != expectedSHA256 → throw .sha256Mismatch
  4. ZIPFoundation.unzip(tmpFile, to: destination)
  5. 删除 tmpFile
```

### 失败兜底

| 失败场景 | 行为 |
|---|---|
| 远程 manifest 拉失败 | 用本地缓存的 manifest,大厅照常渲染 |
| 下载 zip 失败(网络/超时) | 重试 3 次指数退避(1s/2s/4s)→ 最终失败返回 nil |
| SHA256 不匹配 | 删除 tmpFile,返回 nil(可能 OSS 还在传) |
| 解压失败 | 删除目标目录,返回 nil |
| WebView 加载新版连续失败 3 次 | **Phase 3**:回退该游戏上一个本地版本(若存在) |

---

## 六、Hall H5 设计

### 大厅 H5 文件(`Modules/Business/GameModule/Resources/Hall/`)

**hall.html**(单文件入口):
```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
  <link rel="stylesheet" href="hall.css">
</head>
<body>
  <div id="game-grid"></div>
  <script src="hall.js"></script>
</body>
</html>
```

**hall.js**(核心逻辑):
```js
// Native 启动前注入 window.GAME_MANIFEST = { games: [...] }
const manifest = window.GAME_MANIFEST || { games: [] };

const grid = document.getElementById('game-grid');
manifest.games.forEach(game => {
  const card = document.createElement('div');
  card.className = 'game-card';
  card.innerHTML = `<img src="${game.icon}"/><div class="title">${game.title}</div>`;
  card.onclick = () => {
    location.href = `wechat://game/run?id=${game.id}`;
  };
  grid.appendChild(card);
});

if (manifest.games.length === 0) {
  grid.innerHTML = '<div class="empty">暂无游戏,稍后再试</div>';
}
```

**hall.css**:微信风灰底 + 卡片网格(具体样式实现时定)。

### Native 注入 + 加载

```swift
private func loadHallWithManifest() {
    let manifestJSON = encodeManifest(GameBundleManager.shared.currentManifest)
    let injectScript = "window.GAME_MANIFEST = \(manifestJSON);"
    let userScript = WKUserScript(
        source: injectScript,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: true
    )
    webView.configuration.userContentController.addUserScript(userScript)

    guard let hallURL = Bundle(for: Self.self)
            .url(forResource: "hall", withExtension: "html", subdirectory: "Hall") else { return }
    webView.loadFileURL(hallURL, allowingReadAccessTo: hallURL.deletingLastPathComponent())
}
```

**关键点**:
- `injectionTime: .atDocumentStart` 保证 hall.js 执行前 manifest 已注入
- `Bundle(for: Self.self)` 取 GameModule.framework 资源(podspec `s.resources = ['Resources/**/*']`)
- viewDidAppear 触发 refreshManifest → 拿到新 manifest 后 `webView.reload()`,manifest 重新注入

### URL scheme 拦截

```swift
extension GameHallViewController: WKNavigationDelegate {
    public func webView(_ webView: WKWebView,
                        decidePolicyFor action: WKNavigationAction,
                        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else {
            decisionHandler(.allow); return
        }
        if url.scheme == "wechat" {
            decisionHandler(.cancel)
            Router.shared.push(url.absoluteString)
            return
        }
        decisionHandler(.allow)
    }
}
```

---

## 七、GameRunner 设计

### Loading 状态机

```swift
public enum GameLoadState {
    case idle
    case downloading(progress: Double)   // 0.0 ~ 1.0(可选 Phase 2)
    case ready
    case failed(reason: String)
}
```

### VC 流程

```swift
public final class GameRunnerViewController: BaseViewController, PageRoutable {

    public static var routePattern: String { "game/run" }
    public static func createPage(with params: [String: String]) -> UIViewController? {
        guard let gameId = params["id"] else { return nil }
        return GameRunnerViewController(gameId: gameId)
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        setupLoadingView()
        setupErrorView()
        Task { await loadGame() }
    }

    private func loadGame() async {
        state = .downloading(progress: 0)
        guard let localURL = await GameBundleManager.shared.bundleURL(for: gameId) else {
            state = .failed(reason: "游戏加载失败")
            return
        }
        state = .ready
        webView.loadFileURL(localURL, allowingReadAccessTo: localURL.deletingLastPathComponent())
    }
}
```

### WebView 配置

```swift
private static func makeWebView() -> WKWebView {
    let config = WKWebViewConfiguration()
    config.allowsInlineMediaPlayback = true
    config.preferences.javaScriptEnabled = true
    let wv = WKWebView(frame: .zero, configuration: config)
    wv.scrollView.bounces = false
    wv.scrollView.isScrollEnabled = false
    wv.backgroundColor = .black
    wv.isOpaque = false
    return wv
}
```

---

## 八、OSS 目录与 manifest schema

### OSS 完整结构(沿用现有 RN bundle bucket)

```
https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com/
├── ... (RN bundle 的现有结构,不动)
└── games/                                ← 新增
    ├── manifest.json
    ├── 2048/
    │   ├── 2048-v1.0.zip
    │   ├── 2048-v1.1.zip                ← 升级时上传新版,旧版保留作回滚
    │   └── icon.png
    ├── tetris/
    │   ├── tetris-v1.0.zip
    │   └── icon.png
    └── memory/
        ├── memory-v1.0.zip
        └── icon.png
```

### manifest.json 示例

```json
{
  "manifestVersion": 1,
  "updatedAt": "2026-05-30T18:00:00Z",
  "games": [
    {
      "id": "2048",
      "title": "2048",
      "icon": "https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com/games/2048/icon.png",
      "version": "1.0",
      "url": "https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com/games/2048/2048-v1.0.zip",
      "sha256": "ab12cd34...",
      "size": 45678,
      "grayscale": { "percentage": 100, "whitelist": [] }
    },
    {
      "id": "tetris",
      "title": "俄罗斯方块",
      "icon": "https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com/games/tetris/icon.png",
      "version": "1.0",
      "url": "https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com/games/tetris/tetris-v1.0.zip",
      "sha256": "ef56...",
      "size": 67890,
      "grayscale": { "percentage": 100, "whitelist": [] }
    },
    {
      "id": "memory",
      "title": "记忆翻牌",
      "icon": "https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com/games/memory/icon.png",
      "version": "1.0",
      "url": "https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com/games/memory/memory-v1.0.zip",
      "sha256": "...",
      "size": 12345,
      "grayscale": { "percentage": 100, "whitelist": [] }
    }
  ]
}
```

---

## 九、工作流

### 9.1 大厅 H5 维护

- 直接在 `Modules/Business/GameModule/Resources/Hall/` 改 html/css/js
- git commit + pod install(让 pod 重新打包 Resources)
- 编译 + 运行,大厅自动用新版

### 9.2 新增 / 升级游戏(`WeChatGames/scripts/`)

```bash
# 1. 编辑 WeChatGames/2048/ 内容
# 2. 打包
cd WeChatGames
./scripts/build.sh 2048 1.1
# 输出:dist/2048-v1.1.zip, SHA256, manifest 条目片段

# 3. 上传 OSS(aliyun-cli)
./scripts/upload.sh 2048 1.1

# 4. 手动更新 OSS 上的 games/manifest.json(改 version + sha256)
# (Phase 3 可做自动化:upload.sh 顺手更 manifest)

# 5. 客户端下次拉 manifest 自动发现新版,进游戏自动下载
```

### 9.3 灰度发布(Phase 3)

- manifest 把目标游戏 `grayscale.percentage` 改为 30,客户端 deviceId hash 命中前 30% 拿新版
- 观察 N 天稳定 → percentage 改 100,全量
- 出问题 → percentage 改 0 或回滚 version 字段为老版

### 9.4 下架游戏

- manifest.json 删该游戏条目
- 客户端下次刷新 → 大厅不再显示
- 本地缓存惰性清理(可选 Phase 3)

---

## 十、路由

修改 `Modules/WeChatKit/WeChatRouter/Routes.swift`:

```swift
// 改:
public static let game = "wechat://game/hall"          // 原 wechat://rn?page=gameCenter

// 新:
public static let gameRun = "wechat://game/run"        // ?id={gameId}
```

`GameModule.registerRoutes()` 内:
```swift
GameHallViewController.registerPageRoute()
GameRunnerViewController.registerPageRoute()
```

AppDelegate 在 LaunchScheduler 之前调用 `GameModule.registerRoutes()`。

---

## 十一、依赖

- **WCDB**:不需要
- **解压库**:`ZIPFoundation`(纯 Swift,包小,通过 SPM/Pod 引入)
- **CryptoKit**:SHA256 计算(系统自带,iOS 13+)
- **WeChatRouter / WeChatUI / SnapKit / ExtensionKit**:已有

GameModule.podspec 增加:
```ruby
s.dependency 'WeChatUI'
s.dependency 'WeChatRouter'
s.dependency 'ExtensionKit'
s.dependency 'SnapKit'
s.dependency 'ZIPFoundation'
s.resources = ['Resources/**/*']
```

---

## 十二、迭代路径(3 个 Phase)

### Phase 1 — 端到端跑通(~1 周)

**WeChatGames 工程**
- 新建顶层 `HelloRN/WeChatGames/` 目录
- 用 Claude 生成 2048 H5(index.html + main.js + style.css + icon.png + README)
- 写 `scripts/build.sh`,产出 `dist/2048-v1.0.zip` + SHA256
- 手动上传到 OSS games/2048/2048-v1.0.zip
- 编辑 OSS games/manifest.json(只含 2048 一条)

**GameModule pod 骨架**
- 新建 pod + podspec + Podfile 加入
- GameModule.swift + registerRoutes()
- Routes.swift 修改

**Hall H5**
- 编写 hall.html / hall.css / hall.js(渲染卡片网格 + URL scheme 跳转)
- 放入 `Modules/Business/GameModule/Resources/Hall/`

**Native 实现**
- GameManifest model (Codable)
- GameBundleStorage(Documents/Games/ 路径管理)
- GameDownloader(URLSession + SHA256 + ZIPFoundation 解压)
- GameBundleManager(start / refreshManifest / bundleURL,manifest 持久化)
- GameHallViewController(WKWebView + 注入 manifest + URL scheme 拦截)
- GameRunnerViewController(WKWebView + Loading + Error,loadFileURL)

**集成**
- AppDelegate 在 LaunchScheduler 之前调 `GameBundleManager.shared.start(remoteURL:)` + `GameModule.registerRoutes()`
- Discover 入口 `Routes.game` 自动走原生

**验证 (Phase 1 demo)**:
- 启动 → Discover → 游戏 → 大厅显示 2048 一张卡片
- 点击 → "加载中…" → 自动下载 OSS zip → 解压 → WebView 显示 2048 → 能玩

### Phase 2 — 另外 2 款游戏 + 体验完善(~3-5 天)

**WeChatGames**
- AI 生成俄罗斯方块、记忆翻牌(每款 ~3 小时,Claude 大概率 1-2 轮搞定)
- build.sh 各打 zip,上传 OSS,manifest 加 2 条

**Native 完善**
- GameRunnerVC LoadingView 显示下载进度(URLSession.downloadTask progress 回调 → bytes / total → UI 进度条)
- GameRunnerVC ErrorView "重试" 按钮
- GameHallVC viewDidAppear 触发 refreshManifest + reload
- 大厅卡片增强:icon 显示 + size 显示 + "已下载/未下载" 角标

**验证 (Phase 2 demo)**:
- 大厅显示 3 张游戏卡片
- 3 款游戏都能玩
- 下载有进度条
- 失败能重试

### Phase 3 — 灰度 / 回滚 / 文档(~2-3 天)

- 灰度命中:GameBundleManager 解析 grayscale,deviceId hash + percentage + whitelist
- 多版本回滚:GameRunnerVC 加载失败 3 次 → 回退本地上一个 version 加载
- 版本清理:每个游戏只保留最近 2 个版本,老的超 7 天清
- 自动化:scripts/upload.sh 顺手更 manifest.json(用 jq 之类)
- README + Demo 视频

---

## 十三、风险与缓解

| 风险 | 缓解 |
|---|---|
| WKWebView loadFileURL 跨文件读取受限 | `allowingReadAccessTo` 传游戏目录,允许加载同目录 css/js/img |
| 游戏 zip 含恶意 JS | SHA256 校验 + manifest 写权限受控(OSS bucket 我们独占) |
| 大文件下载阻塞 UI | GameBundleManager 全异步,UI 显示进度 + 取消按钮(Phase 2) |
| H5 大厅启动白屏 | loadHTMLString 同步触发,~100ms 内显示卡片(从注入的 manifest 渲染) |
| 解压库选型 | ZIPFoundation(纯 Swift,包小)优先;不行换 SSZipArchive |
| 同一时间多次进同一游戏触发并发下载 | GameBundleManager 内 inFlight 字典 + lock,同 gameId 共享一个下载 Task |
| manifest 升级字段兼容 | manifest.json 用 `manifestVersion` 字段,客户端可识别版本号决定如何解析 |
| WebView 失败白屏(JS 报错) | WKNavigationDelegate.didFail 捕获 → 切 ErrorView |

---

## 十四、未来扩展(不在本次范围)

- **大厅 H5 也走 OSS 热更新**:加 `HallBundleManager`,大厅 URL 从 `Bundle.url` 切换到 `HallBundleManager.localHallURL`
- **AI 五子棋(L2 模式)**:加最小 JS Bridge `Bridge.callAI()`,Native 转发 Claude API,API key 走 Keychain
- **游戏内分享分数到 IM**:扩 Bridge `Bridge.shareScore()`,Native 拉起 IM 会话选择器
- **游戏排行榜**:接后端 / Game Center
- **多人对战**:WebSocket / WebRTC,大改

---

## 十五、面试话术(简历讲法)

> "搭了一套客户端动态化方案,游戏中心从 RN 切到原生 + WebView。大厅是内置的 H5,游戏 H5 走 OSS 远程下发,有 manifest 驱动 + SHA256 校验 + 灰度 + 多版本回滚,跟 RN bundle 是同一套思路两个场景落地。3 款游戏全部 Claude 生成上线,演示 AI Coding 在前端场景的提效。
>
> 大厅和具体游戏的跳转用 URL scheme 拦截,不引入完整 JS Bridge — 大厅 H5 内 `location.href = wechat://game/run?id=...`,Native WKNavigationDelegate 拦截后走原生路由。这种'纯 web 自闭环 + 最小 Native 入口'的形态在小游戏场景特别合适,后期要加 AI 对战之类才扩 Bridge,渐进式。"
