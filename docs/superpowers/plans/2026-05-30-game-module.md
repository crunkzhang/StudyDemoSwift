# 游戏模块(GameModule)实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 spec(`docs/superpowers/specs/2026-05-30-game-module-design.md`)的游戏模块完整落地 — H5 大厅(内置)+ WebView 小游戏(OSS 远程下发)+ 自动更新 / 灰度 / 回滚。

**Architecture:** 新建 `Business/GameModule` Pod 承载 Native(大厅 VC / 游戏运行 VC / BundleManager);新建顶层 `HelloRN/WeChatGames/` 独立前端工程存放游戏 H5 源码 + build/upload scripts;游戏 H5 走 OSS 远程下载 + SHA256 校验 + 多版本本地缓存,跟现有 RNBundleManager 同思路。

**Tech Stack:** Swift 5、UIKit、WKWebView、Combine、Swift Concurrency、CryptoKit(SHA256)、ZIPFoundation(解压)、SnapKit、CocoaPods、XcodeGen、HTML/CSS/JS(纯 web)。

---

## File Structure

### 新建 / 修改文件清单

```
HelloRN/                                          ← 顶层(已存在)
├── WeChatSwift/                                  ← iOS 工程(已有)
│   ├── Modules/Business/
│   │   └── GameModule/                          ← 新建 Pod   [P1]
│   │       ├── GameModule.podspec
│   │       ├── GameModule.swift
│   │       ├── Hall/
│   │       │   └── VC/GameHallViewController.swift
│   │       ├── Runner/
│   │       │   ├── VC/GameRunnerViewController.swift
│   │       │   └── GameLoadState.swift
│   │       ├── BundleManager/
│   │       │   ├── GameBundleManager.swift
│   │       │   ├── GameManifest.swift
│   │       │   ├── GameBundleStorage.swift
│   │       │   └── GameDownloader.swift
│   │       ├── Resources/Hall/                  ← H5 大厅资源(随 app 发版)
│   │       │   ├── hall.html
│   │       │   ├── hall.css
│   │       │   └── hall.js
│   │       └── GameModuleTests/
│   │           ├── GameManifestTests.swift
│   │           └── GameBundleStorageTests.swift
│   ├── Modules/WeChatKit/WeChatRouter/Routes.swift   [修改:game 路由改原生]
│   ├── WeChatSwift/AppDelegate.swift                 [修改:启动 GameBundleManager + registerRoutes]
│   └── Podfile                                       [修改:加 GameModule + ZIPFoundation]
│
└── WeChatGames/                                  ← 新建,游戏前端源码工程   [P1]
    ├── README.md
    ├── 2048/
    │   ├── index.html
    │   ├── main.js
    │   ├── style.css
    │   ├── icon.png
    │   └── README.md
    ├── tetris/                                   [P2]
    │   └── ...
    ├── memory/                                   [P2]
    │   └── ...
    └── scripts/
        ├── build.sh                              [P1]
        └── upload.sh                             [P3]
```

### OSS 上传(由 scripts/build.sh + 手动 / upload.sh 操作)

```
https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com/games/
├── manifest.json
├── 2048/{2048-v1.0.zip, icon.png}              [P1]
├── tetris/{tetris-v1.0.zip, icon.png}          [P2]
└── memory/{memory-v1.0.zip, icon.png}          [P2]
```

---

## 验证策略

- **纯 Swift model / storage 类** (GameManifest, GameBundleStorage):XCTest TDD
- **下载 / Bundle 编排**(GameDownloader, GameBundleManager):集成测试 + 手动验证
- **UI**(GameHallVC, GameRunnerVC):每 Phase 末尾运行 app 手动验证 + 截图
- **H5 游戏**:浏览器先打开 `WeChatGames/2048/index.html` 验证基本可玩,再走 OSS 下载链路在 app 里跑

---

# Phase 1 · 端到端跑通(~1 周)

---

### Task 1: 新建 WeChatGames 顶层工程目录 + README

**Files:**
- Create: `WeChatGames/README.md`
- Create: `WeChatGames/scripts/.gitkeep`(placeholder)

- [ ] **Step 1: 创建目录结构**

```bash
mkdir -p /Users/carlos/HelloRN/WeChatGames/scripts
touch /Users/carlos/HelloRN/WeChatGames/scripts/.gitkeep
```

- [ ] **Step 2: 写 README**

```markdown
# WeChatGames

WeChatSwift 项目的游戏前端源码工程。每个游戏一个目录,内含 H5 静态资源。

## 目录结构

- `2048/` `tetris/` `memory/` — 各游戏源码
- `scripts/build.sh` — 打包指定游戏为 zip + 计算 SHA256
- `scripts/upload.sh` — 上传 zip 到 OSS + 更新 manifest.json

## 工作流

1. 修改游戏代码
2. `./scripts/build.sh <gameId> <version>` 产出 `dist/<gameId>-v<version>.zip`
3. 手动 / `./scripts/upload.sh` 上传 OSS
4. 客户端下次拉 manifest 自动发现新版

## OSS 位置

`https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com/games/`
```

写到 `WeChatGames/README.md`。

- [ ] **Step 3: Commit(在 HelloRN 父目录创建独立 git? 还是同 WeChatSwift 仓库?)**

WeChatGames 是独立工程,但 demo 阶段先放 `HelloRN/` 父目录,**不进入 WeChatSwift 的 git**。

如果 `HelloRN/` 已经是 git repo,直接 `git add WeChatGames && git commit`。
如果不是,先 `cd /Users/carlos/HelloRN && git init && git add WeChatGames && git commit -m "init WeChatGames"`。

确认下:

```bash
cd /Users/carlos/HelloRN && git status 2>&1 | head -3
```

如果 `not a git repository`,跳过本次 commit,后续 Task 14 再处理(可能要做成 WeChatSwift 内部 submodule)。

**Phase 1 简化方案**:WeChatGames 作为本地工作目录,不入 git,只用于生成 zip 上传 OSS。后续如需团队协作再独立 repo。

记录后跳过本步 commit。

---

### Task 2: 用 AI 生成 2048 H5 游戏

**Files:**
- Create: `WeChatGames/2048/index.html`
- Create: `WeChatGames/2048/main.js`
- Create: `WeChatGames/2048/style.css`
- Create: `WeChatGames/2048/icon.png`(占位 64x64 PNG,可手画/AI 生成/找开源 icon)
- Create: `WeChatGames/2048/README.md`

- [ ] **Step 1: AI 生成 2048 游戏代码**

直接用 Claude / Codex 生成完整 2048(纯 HTML + Vanilla JS + CSS,无依赖)。Prompt 参考:

> 请用纯 HTML / Vanilla JS / CSS 实现 2048 游戏,要求:
> - 单文件 index.html 引用同目录 main.js / style.css
> - 4×4 网格,数字合并经典规则
> - 支持手机触摸滑动(左右上下)+ 键盘方向键
> - 顶部显示分数 + "重新开始" 按钮
> - 失败弹"游戏结束,得分 N",可重玩
> - 移动端响应式,占满 viewport
> - 微信绿色调(#07C160)+ 卡片圆角风
> - 代码精简,~150 行 JS 内

把生成的代码写入对应文件。

- [ ] **Step 2: 准备 icon.png**

64×64 像素 PNG,可用以下任一方式:
- Mac 自带"预览"画一个
- 从 emojigraphics 找一个 🎲 / 🎮 emoji 导出 PNG
- 简单方案:用 Sketch / Figma 画绿底白色 "2048" 文字
- 临时占位:Mac terminal `sips -s format png /System/Library/CoreServices/loginwindow.app/Contents/Resources/AppIcon.icns --out icon.png`

放到 `WeChatGames/2048/icon.png`。

- [ ] **Step 3: 写 README**

```markdown
# 2048

经典 2048 游戏。

## 玩法
- 触摸滑动 / 键盘方向键操控
- 相同数字相撞合并为 2 倍
- 目标:合出 2048

## 文件
- `index.html` — 入口,引用同目录 main.js / style.css
- `icon.png` — 64×64 游戏图标

## 构建
`../scripts/build.sh 2048 1.0`
```

- [ ] **Step 4: 浏览器验证**

```bash
cd /Users/carlos/HelloRN/WeChatGames/2048 && open index.html
```

在 Safari / Chrome 验证可玩,无 console error。

---

### Task 3: 写 build.sh 脚本

**Files:**
- Create: `WeChatGames/scripts/build.sh`

- [ ] **Step 1: 写脚本**

```bash
#!/bin/bash
# 用法: ./scripts/build.sh <gameId> <version>
# 例:   ./scripts/build.sh 2048 1.0
# 产出:  dist/<gameId>-v<version>.zip + 打印 SHA256 + manifest 片段

set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "用法: $0 <gameId> <version>"
    exit 1
fi

GAME_ID=$1
VERSION=$2
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DIST_DIR=${ROOT}/dist
ZIP_NAME=${GAME_ID}-v${VERSION}.zip
DIST_PATH=${DIST_DIR}/${ZIP_NAME}

mkdir -p ${DIST_DIR}

cd ${ROOT}/${GAME_ID}
zip -r ${DIST_PATH} . -x "README.md" -x ".DS_Store"
cd ${ROOT}

SHA256=$(shasum -a 256 ${DIST_PATH} | awk '{print $1}')
SIZE=$(wc -c < ${DIST_PATH} | tr -d ' ')

echo ""
echo "✅ Built ${DIST_PATH}"
echo "   SHA256: ${SHA256}"
echo "   Size:   ${SIZE} bytes"
echo ""
echo "Manifest 条目片段(贴到 games/manifest.json):"
cat <<EOF
{
  "id": "${GAME_ID}",
  "title": "${GAME_ID}",
  "icon": "https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com/games/${GAME_ID}/icon.png",
  "version": "${VERSION}",
  "url": "https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com/games/${GAME_ID}/${ZIP_NAME}",
  "sha256": "${SHA256}",
  "size": ${SIZE},
  "grayscale": { "percentage": 100, "whitelist": [] }
}
EOF
```

- [ ] **Step 2: 加可执行权限**

```bash
chmod +x /Users/carlos/HelloRN/WeChatGames/scripts/build.sh
```

- [ ] **Step 3: 跑一次产出 2048-v1.0.zip**

```bash
cd /Users/carlos/HelloRN/WeChatGames && ./scripts/build.sh 2048 1.0
```

Expected: 输出 `✅ Built ...2048-v1.0.zip`,SHA256,manifest 片段。

记下 SHA256 + Size,Task 4 会用到。

---

### Task 4: 上传 2048-v1.0.zip + icon.png 到 OSS + 初始化 games/manifest.json

**Files:**
- Modify(on OSS): `games/manifest.json`(新建)
- Upload: `games/2048/2048-v1.0.zip`、`games/2048/icon.png`

- [ ] **Step 1: 上传到 OSS**

用阿里云 OSS 控制台(Web)或 ossutil:

```bash
# 如安装了 ossutil 并配好 ~/.ossutilconfig:
ossutil cp /Users/carlos/HelloRN/WeChatGames/dist/2048-v1.0.zip \
    oss://cz-rn-bundle/games/2048/2048-v1.0.zip
ossutil cp /Users/carlos/HelloRN/WeChatGames/2048/icon.png \
    oss://cz-rn-bundle/games/2048/icon.png
```

没有 ossutil 就用 OSS Web Console 拖拽上传,目标路径 `games/2048/`。

- [ ] **Step 2: 创建 manifest.json**

本地写一个 `manifest.json`(把 Task 3 输出的 manifest 片段填进去):

```json
{
  "manifestVersion": 1,
  "updatedAt": "2026-05-30T20:00:00Z",
  "games": [
    {
      "id": "2048",
      "title": "2048",
      "icon": "https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com/games/2048/icon.png",
      "version": "1.0",
      "url": "https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com/games/2048/2048-v1.0.zip",
      "sha256": "<填 Task 3 输出的 SHA256>",
      "size": <填 Task 3 输出的 Size>,
      "grayscale": { "percentage": 100, "whitelist": [] }
    }
  ]
}
```

上传到 OSS:

```bash
ossutil cp manifest.json oss://cz-rn-bundle/games/manifest.json
```

- [ ] **Step 3: 浏览器验证 URL 可访问**

打开:
- `https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com/games/manifest.json`
- `https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com/games/2048/2048-v1.0.zip`
- `https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com/games/2048/icon.png`

都能 200 下载。

---

### Task 5: 新建 GameModule Pod 骨架

**Files:**
- Create: `Modules/Business/GameModule/GameModule.podspec`
- Create: `Modules/Business/GameModule/GameModule.swift`
- Modify: `Podfile`

- [ ] **Step 1: 创建目录**

```bash
mkdir -p /Users/carlos/HelloRN/WeChatSwift/Modules/Business/GameModule/Resources/Hall
```

- [ ] **Step 2: 写 podspec**

```ruby
# Modules/Business/GameModule/GameModule.podspec
Pod::Spec.new do |s|
  s.name             = 'GameModule'
  s.version          = '1.0.0'
  s.summary          = '游戏中心:H5 大厅 + WebView 小游戏'
  s.description      = '原生 WKWebView 容器加载 H5 游戏(走 OSS 远程下发),大厅 H5 内置随 app 发版。'
  s.homepage         = 'https://github.com/nicedayzhu/WeChatSwift'
  s.license          = { :type => 'MIT' }
  s.author           = { 'nicedayzhu' => 'nicedayzhu@example.com' }
  s.source           = { :git => '', :tag => s.version.to_s }

  s.ios.deployment_target = '15.1'
  s.swift_version = '5.0'

  s.source_files = '**/*.swift'
  s.exclude_files = 'GameModuleTests/**/*'
  s.resources = ['Resources/**/*']

  s.frameworks = 'UIKit', 'Foundation', 'WebKit'

  s.dependency 'WeChatUI'
  s.dependency 'WeChatRouter'
  s.dependency 'NavigateKit'
  s.dependency 'ExtensionKit'
  s.dependency 'SnapKit'
  s.dependency 'ZIPFoundation'

  s.test_spec 'GameModuleTests' do |ts|
    ts.source_files = 'GameModuleTests/**/*.swift'
    ts.frameworks = 'XCTest'
  end
end
```

- [ ] **Step 3: 写入口文件**

```swift
// Modules/Business/GameModule/GameModule.swift
import UIKit
import WeChatRouter

extension GameModule: ModuleRoutable {
    public static func registerRoutes() {
        GameHallViewController.registerPageRoute()
        GameRunnerViewController.registerPageRoute()
    }
}

public class GameModule {
    public static let shared = GameModule()
    private init() {}
}
```

- [ ] **Step 4: Podfile 加 GameModule + ZIPFoundation**

修改 `Podfile`,在 `# ── Business 层 ──` 区块加:

```ruby
  pod 'GameModule',     :path => 'Modules/Business/GameModule'
```

在 `# ── 三方库 ──` 区块加:

```ruby
  pod 'ZIPFoundation'
```

同步更新 `group_map`:

```ruby
group_map = {
    'Platform'   => %w[WeChatUI WeChatRouter WeChatNetAPI WeChatRN WCIMSDK],
    'Foundation' => %w[ExtensionKit NavigateKit DDNetwork CatonMonitorKit],
    'Business'   => %w[ChatModule ContactModule DiscoverModule MeModule GameModule],
}
```

- [ ] **Step 5: pod install**

```bash
cd /Users/carlos/HelloRN/WeChatSwift && /opt/homebrew/lib/ruby/gems/4.0.0/bin/pod install 2>&1 | tail -5
```

Expected: `Pod installation complete! There are 94+ dependencies` 含 GameModule 和 ZIPFoundation。

- [ ] **Step 6: Commit**

```bash
git add Modules/Business/GameModule Podfile
git commit -m "feat(game): 新建 GameModule Pod 骨架 + ZIPFoundation 依赖"
```

---

### Task 6: GameManifest model (Codable, TDD)

**Files:**
- Create: `Modules/Business/GameModule/BundleManager/GameManifest.swift`
- Test: `Modules/Business/GameModule/GameModuleTests/GameManifestTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
// Modules/Business/GameModule/GameModuleTests/GameManifestTests.swift
import XCTest
@testable import GameModule

final class GameManifestTests: XCTestCase {

    func test_decode_validManifest() throws {
        let json = """
        {
          "manifestVersion": 1,
          "updatedAt": "2026-05-30T20:00:00Z",
          "games": [
            {
              "id": "2048",
              "title": "2048",
              "icon": "https://example.com/icon.png",
              "version": "1.0",
              "url": "https://example.com/2048-v1.0.zip",
              "sha256": "abc123",
              "size": 12345,
              "grayscale": { "percentage": 100, "whitelist": [] }
            }
          ]
        }
        """.data(using: .utf8)!
        let m = try JSONDecoder().decode(GameManifest.self, from: json)
        XCTAssertEqual(m.manifestVersion, 1)
        XCTAssertEqual(m.games.count, 1)
        XCTAssertEqual(m.games[0].id, "2048")
        XCTAssertEqual(m.games[0].sha256, "abc123")
        XCTAssertEqual(m.games[0].grayscale?.percentage, 100)
    }

    func test_decode_missingGrayscale_defaultsNil() throws {
        let json = """
        {
          "manifestVersion": 1,
          "updatedAt": "2026-05-30T20:00:00Z",
          "games": [{
            "id": "2048", "title": "2048", "icon": "x",
            "version": "1.0", "url": "x", "sha256": "x", "size": 1
          }]
        }
        """.data(using: .utf8)!
        let m = try JSONDecoder().decode(GameManifest.self, from: json)
        XCTAssertNil(m.games[0].grayscale)
    }
}
```

- [ ] **Step 2: 跑测试验证失败**

在 Xcode 里 ⌘U 跑测试,或命令行(替换实际 scheme):

```bash
xcodebuild test -workspace WeChatSwift.xcworkspace -scheme WeChatSwift \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -only-testing:GameModule-Unit-Tests/GameManifestTests 2>&1 | tail -10
```

Expected: `Cannot find 'GameManifest' in scope`

- [ ] **Step 3: 实现 GameManifest model**

```swift
// Modules/Business/GameModule/BundleManager/GameManifest.swift
import Foundation

public struct GameManifest: Codable {
    public let manifestVersion: Int
    public let updatedAt: String
    public let games: [GameEntry]
}

public struct GameEntry: Codable {
    public let id: String
    public let title: String
    public let icon: String
    public let version: String
    public let url: String
    public let sha256: String
    public let size: Int
    public let grayscale: Grayscale?
}

public struct Grayscale: Codable {
    public let percentage: Int
    public let whitelist: [String]
}
```

- [ ] **Step 4: pod install + 跑测试通过**

```bash
cd /Users/carlos/HelloRN/WeChatSwift && /opt/homebrew/lib/ruby/gems/4.0.0/bin/pod install 2>&1 | tail -3
```

Xcode ⌘U,Expected: `GameManifestTests passed`.

- [ ] **Step 5: Commit**

```bash
git add Modules/Business/GameModule/BundleManager/GameManifest.swift \
        Modules/Business/GameModule/GameModuleTests/GameManifestTests.swift
git commit -m "feat(game): GameManifest Codable model + Tests"
```

---

### Task 7: GameBundleStorage (路径管理, TDD)

**Files:**
- Create: `Modules/Business/GameModule/BundleManager/GameBundleStorage.swift`
- Test: `Modules/Business/GameModule/GameModuleTests/GameBundleStorageTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
// Modules/Business/GameModule/GameModuleTests/GameBundleStorageTests.swift
import XCTest
@testable import GameModule

final class GameBundleStorageTests: XCTestCase {

    var tmpDir: URL!
    var storage: GameBundleStorage!

    override func setUp() {
        super.setUp()
        tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        storage = GameBundleStorage(rootDir: tmpDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tmpDir)
        super.tearDown()
    }

    func test_gameDir_constructsExpectedPath() {
        let dir = storage.gameDir(id: "2048", version: "1.0")
        XCTAssertEqual(dir.lastPathComponent, "1.0")
        XCTAssertEqual(dir.deletingLastPathComponent().lastPathComponent, "2048")
    }

    func test_indexHTMLURL_pointsToIndexHtml() {
        let url = storage.indexHTMLURL(id: "2048", version: "1.0")
        XCTAssertEqual(url.lastPathComponent, "index.html")
    }

    func test_hasBundle_returnsFalseWhenMissing() {
        XCTAssertFalse(storage.hasBundle(id: "2048", version: "1.0"))
    }

    func test_hasBundle_returnsTrueAfterCreation() throws {
        let dir = storage.gameDir(id: "2048", version: "1.0")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("<html></html>".utf8).write(to: dir.appendingPathComponent("index.html"))
        XCTAssertTrue(storage.hasBundle(id: "2048", version: "1.0"))
    }

    func test_saveAndLoadManifest_roundTrip() throws {
        let m = GameManifest(manifestVersion: 1, updatedAt: "2026", games: [])
        try storage.saveManifest(m)
        let loaded = storage.loadManifest()
        XCTAssertEqual(loaded?.manifestVersion, 1)
    }
}
```

- [ ] **Step 2: 跑测试验证失败**

Xcode ⌘U,Expected: `Cannot find 'GameBundleStorage' in scope`.

- [ ] **Step 3: 实现 GameBundleStorage**

```swift
// Modules/Business/GameModule/BundleManager/GameBundleStorage.swift
import Foundation

public final class GameBundleStorage {
    private let rootDir: URL
    private let fm = FileManager.default

    public init(rootDir: URL = GameBundleStorage.defaultRootDir()) {
        self.rootDir = rootDir
        try? fm.createDirectory(at: rootDir, withIntermediateDirectories: true)
    }

    public static func defaultRootDir() -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("Games", isDirectory: true)
    }

    // MARK: - 路径计算

    /// Documents/Games/{gameId}/{version}/
    public func gameDir(id: String, version: String) -> URL {
        rootDir.appendingPathComponent(id, isDirectory: true)
            .appendingPathComponent(version, isDirectory: true)
    }

    /// Documents/Games/{gameId}/{version}/index.html
    public func indexHTMLURL(id: String, version: String) -> URL {
        gameDir(id: id, version: version).appendingPathComponent("index.html")
    }

    /// 该游戏该版本是否已下载并解压完成
    public func hasBundle(id: String, version: String) -> Bool {
        fm.fileExists(atPath: indexHTMLURL(id: id, version: version).path)
    }

    /// 删除指定游戏指定版本目录
    public func remove(id: String, version: String) throws {
        let dir = gameDir(id: id, version: version)
        if fm.fileExists(atPath: dir.path) {
            try fm.removeItem(at: dir)
        }
    }

    // MARK: - manifest 缓存

    private var manifestPath: URL {
        rootDir.appendingPathComponent("manifest.json")
    }

    public func saveManifest(_ manifest: GameManifest) throws {
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: manifestPath, options: .atomic)
    }

    public func loadManifest() -> GameManifest? {
        guard let data = try? Data(contentsOf: manifestPath) else { return nil }
        return try? JSONDecoder().decode(GameManifest.self, from: data)
    }
}
```

- [ ] **Step 4: 跑测试通过 + Commit**

```bash
cd /Users/carlos/HelloRN/WeChatSwift && /opt/homebrew/lib/ruby/gems/4.0.0/bin/pod install 2>&1 | tail -3
```

Xcode ⌘U,Expected: 5 个 test 全 pass。

```bash
git add Modules/Business/GameModule/BundleManager/GameBundleStorage.swift \
        Modules/Business/GameModule/GameModuleTests/GameBundleStorageTests.swift
git commit -m "feat(game): GameBundleStorage 路径管理 + manifest 缓存(TDD)"
```

---

### Task 8: GameDownloader (URLSession + SHA256 + ZIPFoundation 解压)

**Files:**
- Create: `Modules/Business/GameModule/BundleManager/GameDownloader.swift`

- [ ] **Step 1: 写实现**

```swift
// Modules/Business/GameModule/BundleManager/GameDownloader.swift
import Foundation
import CryptoKit
import ZIPFoundation

public enum GameDownloadError: Error {
    case networkFailed(Error)
    case sha256Mismatch(expected: String, actual: String)
    case unzipFailed(Error)
}

public final class GameDownloader {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// 下载 zip → SHA256 校验 → 解压到 destination 目录
    /// destination 不存在会自动创建;已存在内容会被覆盖。
    public func download(url: URL,
                         expectedSHA256: String,
                         destination: URL) async throws {
        // 1. 下载到临时文件
        let (tmpURL, response) = try await session.download(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw GameDownloadError.networkFailed(
                NSError(domain: "GameDownloader", code: http.statusCode)
            )
        }

        // 2. SHA256 校验
        let data = try Data(contentsOf: tmpURL)
        let actual = SHA256.hash(data: data).compactMap { String(format: "%02x", $0) }.joined()
        guard actual.lowercased() == expectedSHA256.lowercased() else {
            try? FileManager.default.removeItem(at: tmpURL)
            throw GameDownloadError.sha256Mismatch(expected: expectedSHA256, actual: actual)
        }

        // 3. 准备 destination(清空旧的)
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)

        // 4. ZIPFoundation 解压
        do {
            try fm.unzipItem(at: tmpURL, to: destination)
        } catch {
            try? fm.removeItem(at: destination)
            throw GameDownloadError.unzipFailed(error)
        }

        // 5. 清理临时文件
        try? fm.removeItem(at: tmpURL)
    }
}
```

- [ ] **Step 2: 编译验证(无测试,纯网络 IO 集成在 BundleManager 测)**

Xcode ⌘B,Expected: `BUILD SUCCEEDED`.

- [ ] **Step 3: Commit**

```bash
cd /Users/carlos/HelloRN/WeChatSwift && /opt/homebrew/lib/ruby/gems/4.0.0/bin/pod install 2>&1 | tail -3
git add Modules/Business/GameModule/BundleManager/GameDownloader.swift
git commit -m "feat(game): GameDownloader 下载 + SHA256 + ZIPFoundation 解压"
```

---

### Task 9: GameBundleManager (单例 + 协调 + 自动更新)

**Files:**
- Create: `Modules/Business/GameModule/BundleManager/GameBundleManager.swift`

- [ ] **Step 1: 实现 GameBundleManager**

```swift
// Modules/Business/GameModule/BundleManager/GameBundleManager.swift
import Foundation

public final class GameBundleManager {
    public static let shared = GameBundleManager()

    private let storage: GameBundleStorage
    private let downloader: GameDownloader
    private var remoteURL: URL?
    private var pollTimer: Timer?

    /// 当前 manifest 缓存(供大厅渲染 + 注入 H5)
    public private(set) var currentManifest: GameManifest?

    /// 同 gameId 并发请求合并(避免重复下载)
    private var inFlightDownloads: [String: Task<URL?, Never>] = [:]
    private let lock = NSLock()

    public init(storage: GameBundleStorage = GameBundleStorage(),
                downloader: GameDownloader = GameDownloader()) {
        self.storage = storage
        self.downloader = downloader
        // 启动时加载磁盘缓存
        self.currentManifest = storage.loadManifest()
    }

    /// AppDelegate 启动调,触发后台拉 manifest + 30min 轮询
    public func start(remoteURL: String) {
        guard let url = URL(string: remoteURL) else { return }
        self.remoteURL = url

        // 后台首次拉
        Task { await self.refreshManifest() }

        // 30 分钟轮询
        DispatchQueue.main.async { [weak self] in
            self?.pollTimer?.invalidate()
            self?.pollTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
                Task { await self?.refreshManifest() }
            }
        }
    }

    /// 拉远程 manifest → 解析 → 写本地缓存 → 更新 currentManifest
    public func refreshManifest() async {
        guard let url = remoteURL else { return }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                print("[Game] manifest fetch HTTP \(http.statusCode)")
                return
            }
            let manifest = try JSONDecoder().decode(GameManifest.self, from: data)
            try storage.saveManifest(manifest)
            currentManifest = manifest
            print("[Game] ✅ manifest refreshed, games=\(manifest.games.count)")
        } catch {
            print("[Game] ❌ manifest refresh failed: \(error)")
        }
    }

    /// 拿某个游戏的本地 index.html 路径(命中本地直接返回,否则下载)
    public func bundleURL(for gameId: String) async -> URL? {
        guard let game = currentManifest?.games.first(where: { $0.id == gameId }) else {
            print("[Game] 游戏 \(gameId) 不在 manifest 内")
            return nil
        }

        // 1. 已下载且版本一致 → 直接返回
        if storage.hasBundle(id: gameId, version: game.version) {
            return storage.indexHTMLURL(id: gameId, version: game.version)
        }

        // 2. 同 gameId 并发请求合并
        lock.lock()
        if let inFlight = inFlightDownloads[gameId] {
            lock.unlock()
            return await inFlight.value
        }
        let task = Task<URL?, Never> { [weak self] in
            await self?.performDownload(game: game)
        }
        inFlightDownloads[gameId] = task
        lock.unlock()

        let result = await task.value
        lock.lock()
        inFlightDownloads.removeValue(forKey: gameId)
        lock.unlock()
        return result
    }

    private func performDownload(game: GameEntry) async -> URL? {
        guard let url = URL(string: game.url) else { return nil }
        let destination = storage.gameDir(id: game.id, version: game.version)
        do {
            try await downloader.download(
                url: url,
                expectedSHA256: game.sha256,
                destination: destination
            )
            print("[Game] ✅ 下载完成 \(game.id) v\(game.version)")
            return storage.indexHTMLURL(id: game.id, version: game.version)
        } catch {
            print("[Game] ❌ 下载失败 \(game.id) v\(game.version): \(error)")
            return nil
        }
    }
}
```

- [ ] **Step 2: 编译 + Commit**

```bash
cd /Users/carlos/HelloRN/WeChatSwift && /opt/homebrew/lib/ruby/gems/4.0.0/bin/pod install 2>&1 | tail -3
```

⌘B,Expected: `BUILD SUCCEEDED`.

```bash
git add Modules/Business/GameModule/BundleManager/GameBundleManager.swift
git commit -m "feat(game): GameBundleManager 单例 + manifest 自动更新 + 并发下载合并"
```

---

### Task 10: Hall H5 资源 (hall.html / hall.css / hall.js)

**Files:**
- Create: `Modules/Business/GameModule/Resources/Hall/hall.html`
- Create: `Modules/Business/GameModule/Resources/Hall/hall.css`
- Create: `Modules/Business/GameModule/Resources/Hall/hall.js`

- [ ] **Step 1: hall.html**

```html
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
  <title>游戏中心</title>
  <link rel="stylesheet" href="hall.css">
</head>
<body>
  <div id="game-grid"></div>
  <script src="hall.js"></script>
</body>
</html>
```

- [ ] **Step 2: hall.css**

```css
* { box-sizing: border-box; margin: 0; padding: 0; -webkit-tap-highlight-color: transparent; }
body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; background: #EDEDED; min-height: 100vh; }
#game-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 12px;
  padding: 16px;
}
.game-card {
  background: white;
  border-radius: 12px;
  padding: 16px 8px;
  display: flex;
  flex-direction: column;
  align-items: center;
  cursor: pointer;
  transition: transform 0.1s;
}
.game-card:active { transform: scale(0.95); background: #F5F5F5; }
.game-card img {
  width: 56px;
  height: 56px;
  border-radius: 12px;
  object-fit: cover;
  background: #DDD;
}
.game-card .title {
  margin-top: 8px;
  font-size: 13px;
  color: #333;
  text-align: center;
}
.empty {
  grid-column: 1 / -1;
  text-align: center;
  padding: 80px 20px;
  color: #888;
  font-size: 14px;
}
```

- [ ] **Step 3: hall.js**

```js
const manifest = window.GAME_MANIFEST || { games: [] };
const grid = document.getElementById('game-grid');

if (manifest.games.length === 0) {
  grid.innerHTML = '<div class="empty">暂无游戏,稍后再试</div>';
} else {
  manifest.games.forEach(game => {
    const card = document.createElement('div');
    card.className = 'game-card';
    card.innerHTML = `
      <img src="${game.icon}" alt="${game.title}" onerror="this.style.background='#07C160'; this.removeAttribute('src');" />
      <div class="title">${game.title}</div>
    `;
    card.onclick = () => {
      // URL scheme,Native WKNavigationDelegate 拦截
      location.href = `wechat://game/run?id=${encodeURIComponent(game.id)}`;
    };
    grid.appendChild(card);
  });
}
```

- [ ] **Step 4: pod install(让 podspec 把 Resources 重新打进 bundle)**

```bash
cd /Users/carlos/HelloRN/WeChatSwift && /opt/homebrew/lib/ruby/gems/4.0.0/bin/pod install 2>&1 | tail -3
```

- [ ] **Step 5: Commit**

```bash
git add Modules/Business/GameModule/Resources/Hall
git commit -m "feat(game): Hall H5 资源 — 卡片网格 + URL scheme 跳转"
```

---

### Task 11: GameHallViewController (WKWebView + 注入 manifest + URL scheme 拦截)

**Files:**
- Create: `Modules/Business/GameModule/Hall/VC/GameHallViewController.swift`

- [ ] **Step 1: 创建目录 + 实现 VC**

```bash
mkdir -p /Users/carlos/HelloRN/WeChatSwift/Modules/Business/GameModule/Hall/VC
```

```swift
// Modules/Business/GameModule/Hall/VC/GameHallViewController.swift
import UIKit
import WebKit
import SnapKit
import WeChatUI
import WeChatRouter
import NavigateKit

public final class GameHallViewController: BaseViewController, PageRoutable {

    public static var routePattern: String { "game/hall" }
    public static func createPage(with params: [String: String]) -> UIViewController? {
        GameHallViewController()
    }

    private let webView: WKWebView = {
        let config = WKWebViewConfiguration()
        config.preferences.javaScriptEnabled = true
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.backgroundColor = UIColor(white: 0.93, alpha: 1)
        wv.isOpaque = false
        wv.scrollView.bounces = false
        return wv
    }()

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "游戏"
        view.backgroundColor = UIColor(white: 0.93, alpha: 1)

        webView.navigationDelegate = self
        view.addSubview(webView)
        webView.snp.makeConstraints { $0.edges.equalToSuperview() }

        loadHall()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 拉一次 manifest,拿到新数据后 reload(重新走 loadHall → 注入 + 加载)
        Task {
            await GameBundleManager.shared.refreshManifest()
            await MainActor.run { self.loadHall() }
        }
    }

    private func loadHall() {
        // 1. 注入 manifest 到 window.GAME_MANIFEST
        let manifest = GameBundleManager.shared.currentManifest
            ?? GameManifest(manifestVersion: 1, updatedAt: "", games: [])
        let data = (try? JSONEncoder().encode(manifest)) ?? Data("{\"games\":[]}".utf8)
        let json = String(data: data, encoding: .utf8) ?? "{\"games\":[]}"
        let script = "window.GAME_MANIFEST = \(json);"

        webView.configuration.userContentController.removeAllUserScripts()
        webView.configuration.userContentController.addUserScript(WKUserScript(
            source: script,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))

        // 2. 加载内置 hall.html(Bundle 内 Resources/Hall/)
        guard let url = Bundle(for: Self.self)
                .url(forResource: "hall", withExtension: "html", subdirectory: "Hall") else {
            print("[Game] hall.html 找不到 — 检查 podspec s.resources")
            return
        }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
}

// MARK: - WKNavigationDelegate

extension GameHallViewController: WKNavigationDelegate {
    public func webView(_ webView: WKWebView,
                        decidePolicyFor navigationAction: WKNavigationAction,
                        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow); return
        }
        // 拦截自定义 scheme,转给原生 Router
        if url.scheme == "wechat" {
            decisionHandler(.cancel)
            Router.shared.push(url.absoluteString)
            return
        }
        decisionHandler(.allow)
    }
}
```

- [ ] **Step 2: pod install + 编译 + Commit**

```bash
cd /Users/carlos/HelloRN/WeChatSwift && /opt/homebrew/lib/ruby/gems/4.0.0/bin/pod install 2>&1 | tail -3
```

⌘B Expected: `BUILD SUCCEEDED`.

```bash
git add Modules/Business/GameModule/Hall
git commit -m "feat(game): GameHallViewController WKWebView + 注入 manifest + URL scheme 拦截"
```

---

### Task 12: GameRunnerViewController + GameLoadState

**Files:**
- Create: `Modules/Business/GameModule/Runner/GameLoadState.swift`
- Create: `Modules/Business/GameModule/Runner/VC/GameRunnerViewController.swift`

- [ ] **Step 1: 创建目录 + GameLoadState**

```bash
mkdir -p /Users/carlos/HelloRN/WeChatSwift/Modules/Business/GameModule/Runner/VC
```

```swift
// Modules/Business/GameModule/Runner/GameLoadState.swift
import Foundation

public enum GameLoadState {
    case idle
    case downloading                  // Phase 1 不显示进度,简单 spinner
    case ready
    case failed(reason: String)
}
```

- [ ] **Step 2: GameRunnerViewController**

```swift
// Modules/Business/GameModule/Runner/VC/GameRunnerViewController.swift
import UIKit
import WebKit
import SnapKit
import WeChatUI
import WeChatRouter
import NavigateKit

public final class GameRunnerViewController: BaseViewController, PageRoutable {

    public static var routePattern: String { "game/run" }
    public static func createPage(with params: [String: String]) -> UIViewController? {
        guard let id = params["id"] else { return nil }
        return GameRunnerViewController(gameId: id)
    }

    private let gameId: String
    private let webView: WKWebView
    private let loadingView = UIActivityIndicatorView(style: .large)
    private let errorLabel: UILabel = {
        let l = UILabel()
        l.textColor = .white
        l.font = .systemFont(ofSize: 14)
        l.textAlignment = .center
        l.numberOfLines = 0
        l.isHidden = true
        return l
    }()

    private var state: GameLoadState = .idle {
        didSet { applyState() }
    }

    public init(gameId: String) {
        self.gameId = gameId
        self.webView = Self.makeWebView()
        super.init(nibName: nil, bundle: nil)
        title = gameId
    }
    required init?(coder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.addSubview(webView)
        view.addSubview(loadingView)
        view.addSubview(errorLabel)
        webView.snp.makeConstraints { $0.edges.equalToSuperview() }
        loadingView.snp.makeConstraints { $0.center.equalToSuperview() }
        errorLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(20)
            make.trailing.lessThanOrEqualToSuperview().offset(-20)
        }
        Task { await loadGame() }
    }

    private func loadGame() async {
        await MainActor.run { self.state = .downloading }
        guard let localURL = await GameBundleManager.shared.bundleURL(for: gameId) else {
            await MainActor.run { self.state = .failed(reason: "游戏加载失败") }
            return
        }
        await MainActor.run {
            self.state = .ready
            self.webView.loadFileURL(localURL, allowingReadAccessTo: localURL.deletingLastPathComponent())
        }
    }

    private func applyState() {
        switch state {
        case .idle:
            loadingView.isHidden = true
            errorLabel.isHidden = true
            webView.isHidden = true
        case .downloading:
            loadingView.startAnimating()
            loadingView.isHidden = false
            errorLabel.isHidden = true
            webView.isHidden = true
        case .ready:
            loadingView.stopAnimating()
            loadingView.isHidden = true
            errorLabel.isHidden = true
            webView.isHidden = false
        case .failed(let reason):
            loadingView.stopAnimating()
            loadingView.isHidden = true
            errorLabel.text = reason
            errorLabel.isHidden = false
            webView.isHidden = true
        }
    }

    private static func makeWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.preferences.javaScriptEnabled = true
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.backgroundColor = .black
        wv.isOpaque = false
        wv.scrollView.bounces = false
        wv.scrollView.isScrollEnabled = false
        return wv
    }
}
```

- [ ] **Step 3: pod install + 编译 + Commit**

```bash
cd /Users/carlos/HelloRN/WeChatSwift && /opt/homebrew/lib/ruby/gems/4.0.0/bin/pod install 2>&1 | tail -3
```

⌘B Expected: `BUILD SUCCEEDED`.

```bash
git add Modules/Business/GameModule/Runner
git commit -m "feat(game): GameRunnerViewController WKWebView + 状态机 + loadFileURL"
```

---

### Task 13: 修改 Routes.swift + AppDelegate 启动 GameBundleManager + 注册路由

**Files:**
- Modify: `Modules/WeChatKit/WeChatRouter/Routes.swift`
- Modify: `WeChatSwift/AppDelegate.swift`

- [ ] **Step 1: 改 Routes**

```bash
grep -n "static let game" /Users/carlos/HelloRN/WeChatSwift/Modules/WeChatKit/WeChatRouter/Routes.swift
```

修改 `Routes.swift`:

```swift
// 改:
public static let game        = "wechat://game/hall"      // 之前是 "wechat://rn?page=gameCenter"

// 新增:
public static let gameRun     = "wechat://game/run"
```

- [ ] **Step 2: AppDelegate 启动 GameBundleManager + 注册路由**

`WeChatSwift/AppDelegate.swift` 增加 `import GameModule`,在 `LaunchScheduler.start()` 之前(跟 `ChatModule.registerRoutes()` 同位置)增加:

```swift
import GameModule

// ... 在 LaunchScheduler.shared.start() 之前
GameBundleManager.shared.start(
    remoteURL: "https://cz-rn-bundle.oss-cn-hangzhou.aliyuncs.com/games/manifest.json"
)
GameModule.registerRoutes()
```

- [ ] **Step 3: 编译 + 运行验证 + Commit**

```bash
cd /Users/carlos/HelloRN/WeChatSwift && /opt/homebrew/lib/ruby/gems/4.0.0/bin/pod install 2>&1 | tail -3
```

Xcode ⌘R 跑模拟器:
- Discover tab → 点击"游戏" → 进入 GameHallViewController
- 应看到 2048 卡片(图标 + 标题)
- console 应有:`[Game] ✅ manifest refreshed, games=1`
- 点击 2048 卡片 → 进入 GameRunnerViewController → loading 转圈 → 下载 → WebView 显示 2048 → 能玩

```bash
git add Modules/WeChatKit/WeChatRouter/Routes.swift WeChatSwift/AppDelegate.swift
git commit -m "feat(game): Routes.game 切原生 + AppDelegate 启动 GameBundleManager + registerRoutes"
```

---

### Task 14: Phase 1 集成验证 + Demo 记录

**Files:** (无新增,验证 + 简单记录)

- [ ] **Step 1: 完整跑一遍 Phase 1 demo**

模拟器 ⌘R:
1. 启动 app → 等几秒(让 manifest 后台拉好)
2. Discover tab → "游戏" → 大厅显示 2048 卡片
3. 点击 → 短暂 loading(首次需下载)→ 进入 2048 游戏
4. 玩两步验证游戏能正常交互
5. 返回大厅 → 再点击 2048 → 这次秒开(本地缓存命中)
6. 杀进程重启 → 再进 → 仍秒开(磁盘缓存)

- [ ] **Step 2: 检查 console 日志关键节点**

应看到:
```
[Game] ✅ manifest refreshed, games=1
[Game] ✅ 下载完成 2048 v1.0          (首次进游戏时)
```

- [ ] **Step 3: Phase 1 commit(标记完成)**

```bash
git commit --allow-empty -m "milestone(game): Phase 1 端到端跑通 — 2048 OSS 下发 + 大厅 + 游戏"
```

---

# Phase 2 · 另外 2 款游戏 + 体验完善(~3-5 天)

---

### Task 15: AI 生成俄罗斯方块 H5 + 上传 OSS + 更 manifest

**Files:**
- Create: `WeChatGames/tetris/{index.html,main.js,style.css,icon.png,README.md}`

- [ ] **Step 1: AI 生成俄罗斯方块**

Claude / Codex prompt:

> 用 Vanilla HTML/JS/CSS 实现俄罗斯方块,要求:
> - 单文件 index.html 引用同目录 main.js / style.css
> - 10×20 网格,7 种经典方块(I/O/T/L/J/S/Z),颜色对应
> - 移动端触摸控制:左滑 = 左移、右滑 = 右移、上滑 = 旋转、下滑 = 软降
> - 键盘:方向键(左右移动 + 上旋转 + 下软降)+ 空格 = 硬降
> - 顶部显示分数 + 行数 + "重新开始"按钮
> - 游戏结束弹窗 + 重玩
> - 移动端响应式,占满 viewport
> - 微信绿 #07C160 主题色
> - 代码精简

放入 `WeChatGames/tetris/`,准备 icon.png。

- [ ] **Step 2: 浏览器验证**

```bash
cd /Users/carlos/HelloRN/WeChatGames/tetris && open index.html
```

- [ ] **Step 3: build + 上传**

```bash
cd /Users/carlos/HelloRN/WeChatGames && ./scripts/build.sh tetris 1.0
# 记下 SHA256 + Size
ossutil cp dist/tetris-v1.0.zip oss://cz-rn-bundle/games/tetris/tetris-v1.0.zip
ossutil cp tetris/icon.png oss://cz-rn-bundle/games/tetris/icon.png
```

- [ ] **Step 4: 手动更 OSS 上的 games/manifest.json**

下载现有 manifest.json(`ossutil cp oss://cz-rn-bundle/games/manifest.json ./`),
手动加 tetris 条目(参考 Task 4 格式),再上传回去。

- [ ] **Step 5: app 内验证**

模拟器 ⌘R → 进游戏中心 → 应看到 2048 + 俄罗斯方块 两张卡片(manifest 后台拉新版后,viewDidAppear 触发 reload)。

如果不显示新游戏,杀进程重启(强制 manifest 重拉)。

- [ ] **Step 6: Commit(只 commit Native 测试无 commit,游戏 H5 不入 git)**

无需 commit,游戏 H5 在 WeChatGames 不入 WeChatSwift git。

---

### Task 16: AI 生成记忆翻牌 H5 + 上传 OSS + 更 manifest

**Files:**
- Create: `WeChatGames/memory/{index.html,main.js,style.css,icon.png,README.md}`

- [ ] **Step 1: AI 生成记忆翻牌**

Claude / Codex prompt:

> 用 Vanilla HTML/JS/CSS 实现记忆翻牌,要求:
> - 单文件 index.html 引用同目录 main.js / style.css
> - 4×4 网格,8 对图案(emoji 即可:🐶🐱🐭🐹🐰🦊🐻🐼)
> - 点击翻牌,匹配则保持翻开,不匹配 1 秒后翻回
> - 全部匹配 → 弹窗"完成!用时 N 秒,翻牌 N 次"
> - 顶部:已用时间 + 翻牌次数 + "重新开始"
> - 移动端响应式
> - 微信绿主题色
> - 代码精简

放入 `WeChatGames/memory/`。

- [ ] **Step 2: 浏览器验证**

- [ ] **Step 3: build + 上传 OSS + 更 manifest**

```bash
cd /Users/carlos/HelloRN/WeChatGames && ./scripts/build.sh memory 1.0
ossutil cp dist/memory-v1.0.zip oss://cz-rn-bundle/games/memory/memory-v1.0.zip
ossutil cp memory/icon.png oss://cz-rn-bundle/games/memory/icon.png
```

更 manifest.json,加 memory 条目,上传。

- [ ] **Step 4: app 验证 3 个游戏都显示**

模拟器,游戏中心应有 3 张卡片,3 款都可玩。

---

### Task 17: GameRunnerVC 加 ErrorView + 重试按钮

**Files:**
- Modify: `Modules/Business/GameModule/Runner/VC/GameRunnerViewController.swift`

- [ ] **Step 1: 加 ErrorView 容器**

修改 `GameRunnerViewController`:

把 errorLabel 替换为 ErrorView 容器(label + 重试按钮):

```swift
// 在 properties 区
private let errorContainer = UIView()
private let errorLabel: UILabel = {
    let l = UILabel()
    l.textColor = .white
    l.font = .systemFont(ofSize: 14)
    l.textAlignment = .center
    l.numberOfLines = 0
    return l
}()
private let retryButton: UIButton = {
    let b = UIButton(type: .system)
    b.setTitle("重试", for: .normal)
    b.setTitleColor(.white, for: .normal)
    b.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
    b.backgroundColor = UIColor(red: 0.027, green: 0.756, blue: 0.376, alpha: 1)
    b.layer.cornerRadius = 8
    b.contentEdgeInsets = UIEdgeInsets(top: 8, left: 24, bottom: 8, right: 24)
    return b
}()
```

viewDidLoad 内 setup:

```swift
errorContainer.isHidden = true
errorContainer.addSubview(errorLabel)
errorContainer.addSubview(retryButton)
view.addSubview(errorContainer)

errorContainer.snp.makeConstraints { make in
    make.center.equalToSuperview()
    make.leading.greaterThanOrEqualToSuperview().offset(20)
    make.trailing.lessThanOrEqualToSuperview().offset(-20)
}
errorLabel.snp.makeConstraints { make in
    make.top.leading.trailing.equalToSuperview()
}
retryButton.snp.makeConstraints { make in
    make.top.equalTo(errorLabel.snp.bottom).offset(16)
    make.centerX.equalToSuperview()
    make.bottom.equalToSuperview()
}
retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
```

applyState 内更新 .failed 分支:

```swift
case .failed(let reason):
    loadingView.stopAnimating()
    loadingView.isHidden = true
    errorLabel.text = reason
    errorContainer.isHidden = false
    webView.isHidden = true
```

`.idle`、`.downloading`、`.ready` 三个分支都要把 `errorContainer.isHidden = true`。

加 retry 方法:

```swift
@objc private func retryTapped() {
    Task { await loadGame() }
}
```

- [ ] **Step 2: 编译 + Commit**

```bash
cd /Users/carlos/HelloRN/WeChatSwift && /opt/homebrew/lib/ruby/gems/4.0.0/bin/pod install 2>&1 | tail -3
```

⌘B Expected: `BUILD SUCCEEDED`.

```bash
git add Modules/Business/GameModule/Runner/VC/GameRunnerViewController.swift
git commit -m "feat(game): GameRunnerVC 加 ErrorView + 重试按钮"
```

---

### Task 18: GameRunnerVC 加 "下载中..." 文案

**Files:**
- Modify: `Modules/Business/GameModule/Runner/VC/GameRunnerViewController.swift`

**说明**:`URLSession.download(from:)` 不带 progress 回调,要精确进度需要 `URLSessionDownloadDelegate` 大改。
Phase 2 只加 spinner 旁边的 "下载中..." 文案让 UI 不冷清,**精确进度延后**(YAGNI)。
GameLoadState 保持 Task 12 原样,不加 progress 字段。

- [ ] **Step 1: 加 loadingLabel 属性**

`GameRunnerViewController.swift` properties 区加:

```swift
private let loadingLabel: UILabel = {
    let l = UILabel()
    l.textColor = .white
    l.font = .systemFont(ofSize: 13)
    l.textAlignment = .center
    l.isHidden = true
    return l
}()
```

- [ ] **Step 2: viewDidLoad 加 loadingLabel 布局**

```swift
view.addSubview(loadingLabel)
loadingLabel.snp.makeConstraints { make in
    make.top.equalTo(loadingView.snp.bottom).offset(12)
    make.centerX.equalToSuperview()
}
```

- [ ] **Step 3: applyState 更新各分支的 loadingLabel 显隐**

`.downloading` 分支显示 "下载中...",其他分支隐藏:

```swift
case .idle:
    loadingView.isHidden = true
    loadingLabel.isHidden = true
    errorContainer.isHidden = true
    webView.isHidden = true
case .downloading:
    loadingView.startAnimating()
    loadingView.isHidden = false
    loadingLabel.text = "下载中..."
    loadingLabel.isHidden = false
    errorContainer.isHidden = true
    webView.isHidden = true
case .ready:
    loadingView.stopAnimating()
    loadingView.isHidden = true
    loadingLabel.isHidden = true
    errorContainer.isHidden = true
    webView.isHidden = false
case .failed(let reason):
    loadingView.stopAnimating()
    loadingView.isHidden = true
    loadingLabel.isHidden = true
    errorLabel.text = reason
    errorContainer.isHidden = false
    webView.isHidden = true
```

- [ ] **Step 4: 编译 + Commit**

```bash
cd /Users/carlos/HelloRN/WeChatSwift && /opt/homebrew/lib/ruby/gems/4.0.0/bin/pod install 2>&1 | tail -3
```

⌘B Expected: `BUILD SUCCEEDED`.

```bash
git add Modules/Business/GameModule/Runner
git commit -m "feat(game): GameRunnerVC 加'下载中...'文案 + spinner(精确进度 Phase 3 完善)"
```

---

### Task 19: 大厅 H5 卡片增强(显示 size + "已下载/未下载"角标)

**Files:**
- Modify: `Modules/Business/GameModule/Resources/Hall/hall.css`
- Modify: `Modules/Business/GameModule/Resources/Hall/hall.js`
- Modify: `Modules/Business/GameModule/Hall/VC/GameHallViewController.swift`(注入额外字段)

- [ ] **Step 1: VC 注入 downloaded 状态到每个 game**

修改 `loadHall()`,在序列化 manifest 之前给每个 game 加 `downloaded` 字段:

```swift
private func loadHall() {
    // 拼一个临时 dict,加 downloaded 字段
    let manifest = GameBundleManager.shared.currentManifest
        ?? GameManifest(manifestVersion: 1, updatedAt: "", games: [])

    let gamesWithStatus: [[String: Any]] = manifest.games.map { g in
        let downloaded = GameBundleStorage().hasBundle(id: g.id, version: g.version)
        return [
            "id": g.id,
            "title": g.title,
            "icon": g.icon,
            "version": g.version,
            "size": g.size,
            "downloaded": downloaded
        ]
    }
    let wrapper: [String: Any] = ["games": gamesWithStatus]
    let data = (try? JSONSerialization.data(withJSONObject: wrapper)) ?? Data("{\"games\":[]}".utf8)
    let json = String(data: data, encoding: .utf8) ?? "{\"games\":[]}"
    let script = "window.GAME_MANIFEST = \(json);"

    webView.configuration.userContentController.removeAllUserScripts()
    webView.configuration.userContentController.addUserScript(WKUserScript(
        source: script,
        injectionTime: .atDocumentStart,
        forMainFrameOnly: true
    ))

    guard let url = Bundle(for: Self.self)
            .url(forResource: "hall", withExtension: "html", subdirectory: "Hall") else { return }
    webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
}
```

- [ ] **Step 2: hall.js 渲染角标 + 大小**

```js
const manifest = window.GAME_MANIFEST || { games: [] };
const grid = document.getElementById('game-grid');

function fmtSize(bytes) {
  if (bytes < 1024) return bytes + 'B';
  if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(0) + 'K';
  return (bytes / 1024 / 1024).toFixed(1) + 'M';
}

if (manifest.games.length === 0) {
  grid.innerHTML = '<div class="empty">暂无游戏,稍后再试</div>';
} else {
  manifest.games.forEach(game => {
    const badge = game.downloaded
      ? '<span class="badge installed">已下载</span>'
      : `<span class="badge new">${fmtSize(game.size)}</span>`;
    const card = document.createElement('div');
    card.className = 'game-card';
    card.innerHTML = `
      <img src="${game.icon}" alt="${game.title}" onerror="this.style.background='#07C160'; this.removeAttribute('src');" />
      <div class="title">${game.title}</div>
      ${badge}
    `;
    card.onclick = () => {
      location.href = `wechat://game/run?id=${encodeURIComponent(game.id)}`;
    };
    grid.appendChild(card);
  });
}
```

- [ ] **Step 3: hall.css 加 badge 样式**

```css
.game-card { position: relative; }
.badge {
  position: absolute;
  top: 6px;
  right: 6px;
  font-size: 10px;
  padding: 2px 6px;
  border-radius: 8px;
}
.badge.installed {
  background: rgba(7, 193, 96, 0.15);
  color: #07C160;
}
.badge.new {
  background: rgba(0, 0, 0, 0.08);
  color: #666;
}
```

- [ ] **Step 4: pod install + 验证 + Commit**

```bash
cd /Users/carlos/HelloRN/WeChatSwift && /opt/homebrew/lib/ruby/gems/4.0.0/bin/pod install 2>&1 | tail -3
```

⌘R 验证大厅卡片有 "已下载" / 文件大小角标。

```bash
git add Modules/Business/GameModule/Resources/Hall \
        Modules/Business/GameModule/Hall/VC/GameHallViewController.swift
git commit -m "feat(game): 大厅卡片显示文件大小 + 已下载角标"
```

---

### Task 20: Phase 2 集成验证

- [ ] **Step 1: 完整跑 Phase 2 demo**

⌘R:
1. 启动 → 进游戏中心 → 3 张卡片(2048、俄罗斯方块、记忆翻牌)
2. 第一次进每个游戏 → 显示"下载中...",~1-3 秒后进入
3. 再次进入 → 卡片角标变 "已下载",秒开
4. 制造下载失败(改 manifest 的 sha256 为错的)→ 进游戏看到"游戏加载失败 / 重试"按钮 → 点重试

- [ ] **Step 2: Phase 2 milestone commit**

```bash
git commit --allow-empty -m "milestone(game): Phase 2 完成 — 3 款游戏 + ErrorView/重试 + 角标"
```

---

# Phase 3 · 灰度 + 回滚 + 文档(~2-3 天)

---

### Task 21: 灰度命中逻辑(deviceId hash + percentage + whitelist)

**Files:**
- Modify: `Modules/Business/GameModule/BundleManager/GameBundleManager.swift`

- [ ] **Step 1: 加 deviceId 获取 helper**

```swift
private static let deviceIdKey = "GameModule.deviceId"
private static var deviceId: String {
    if let cached = UserDefaults.standard.string(forKey: deviceIdKey) {
        return cached
    }
    let new = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
    UserDefaults.standard.set(new, forKey: deviceIdKey)
    return new
}
```

(需要 `import UIKit`,如果 GameBundleManager 没 import 加上)

- [ ] **Step 2: 灰度判断**

加 helper:

```swift
private static func grayscaleHit(game: GameEntry) -> Bool {
    guard let g = game.grayscale else { return true }
    // 白名单优先
    if g.whitelist.contains(deviceId) { return true }
    // 百分比命中(deviceId hash 取模)
    let hash = abs(deviceId.unicodeScalars.reduce(0) { $0 &+ Int($1.value) })
    let bucket = hash % 100
    return bucket < g.percentage
}
```

- [ ] **Step 3: bundleURL 用灰度过滤**

修改 `bundleURL(for:)` 内 game 查找:

```swift
public func bundleURL(for gameId: String) async -> URL? {
    guard let game = currentManifest?.games.first(where: { $0.id == gameId }) else {
        return nil
    }
    // 灰度未命中 → 不下载,返回 nil(大厅根据"是否在 manifest"过滤,
    // 这里只针对 bundleURL 内已经被点击的游戏防御)
    guard Self.grayscaleHit(game: game) else {
        print("[Game] \(gameId) 灰度未命中,跳过下载")
        return nil
    }
    // ... 原流程
}
```

类似的,GameHallViewController.loadHall 也按灰度过滤显示的游戏:

```swift
let visibleGames = manifest.games.filter { GameBundleManager.grayscaleHit(game: $0) }
let gamesWithStatus = visibleGames.map { g in ... }
```

(把 `grayscaleHit` 改为 `internal static`,GameHallViewController 同 pod 可访问)

- [ ] **Step 4: pod install + 编译 + Commit**

```bash
cd /Users/carlos/HelloRN/WeChatSwift && /opt/homebrew/lib/ruby/gems/4.0.0/bin/pod install 2>&1 | tail -3
```

⌘B Expected: `BUILD SUCCEEDED`.

```bash
git add Modules/Business/GameModule/BundleManager/GameBundleManager.swift \
        Modules/Business/GameModule/Hall/VC/GameHallViewController.swift
git commit -m "feat(game): 灰度命中(deviceId hash + percentage + whitelist),大厅 + bundleURL 双层过滤"
```

---

### Task 22: 加载失败回退本地上一版本

**Files:**
- Modify: `Modules/Business/GameModule/BundleManager/GameBundleStorage.swift`(加 listVersions)
- Modify: `Modules/Business/GameModule/BundleManager/GameBundleManager.swift`(加 fallbackBundleURL)
- Modify: `Modules/Business/GameModule/Runner/VC/GameRunnerViewController.swift`(失败时尝试 fallback)

- [ ] **Step 1: GameBundleStorage 加 listVersions**

```swift
/// 列出某游戏所有已下载的版本(按字符串排序倒序,新版在前)
public func listVersions(id: String) -> [String] {
    let gameRoot = rootDir.appendingPathComponent(id, isDirectory: true)
    guard let contents = try? fm.contentsOfDirectory(atPath: gameRoot.path) else {
        return []
    }
    return contents
        .filter { fm.fileExists(atPath: gameRoot.appendingPathComponent($0)
                                     .appendingPathComponent("index.html").path) }
        .sorted(by: >)
}
```

- [ ] **Step 2: GameBundleManager 加 fallbackBundleURL**

```swift
/// 拿当前 manifest 版本之外的最近本地可用版本(回滚用)
public func fallbackBundleURL(for gameId: String) -> URL? {
    guard let currentVersion = currentManifest?.games.first(where: { $0.id == gameId })?.version else {
        return nil
    }
    let versions = storage.listVersions(id: gameId)
    // 跳过当前版本(刚加载失败的),取下一个
    guard let prev = versions.first(where: { $0 != currentVersion }) else {
        return nil
    }
    print("[Game] 回退到本地版本 \(gameId) v\(prev)")
    return storage.indexHTMLURL(id: gameId, version: prev)
}
```

- [ ] **Step 3: GameRunnerVC 加载失败尝试 fallback**

修改 `loadGame()`:

```swift
private func loadGame(useFallback: Bool = false) async {
    await MainActor.run { self.state = .downloading }

    let localURL: URL?
    if useFallback {
        localURL = GameBundleManager.shared.fallbackBundleURL(for: gameId)
    } else {
        localURL = await GameBundleManager.shared.bundleURL(for: gameId)
    }

    guard let url = localURL else {
        // 没新版可下,也没老版可回退
        if !useFallback {
            // 第一次失败 → 尝试 fallback
            await loadGame(useFallback: true)
        } else {
            await MainActor.run { self.state = .failed(reason: "游戏加载失败") }
        }
        return
    }
    await MainActor.run {
        self.state = .ready
        self.webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
}
```

- [ ] **Step 4: pod install + 编译 + Commit**

```bash
cd /Users/carlos/HelloRN/WeChatSwift && /opt/homebrew/lib/ruby/gems/4.0.0/bin/pod install 2>&1 | tail -3
```

⌘B Expected: `BUILD SUCCEEDED`.

```bash
git add Modules/Business/GameModule/BundleManager Modules/Business/GameModule/Runner
git commit -m "feat(game): 新版加载失败自动回退本地上一版本(GameBundleStorage.listVersions)"
```

---

### Task 23: scripts/upload.sh 自动化上传 + 更 manifest(jq)

**Files:**
- Create: `WeChatGames/scripts/upload.sh`

- [ ] **Step 1: 写 upload.sh**

```bash
#!/bin/bash
# 用法: ./scripts/upload.sh <gameId> <version>
# 自动:
# 1. 上传 dist/<gameId>-v<version>.zip 到 OSS
# 2. 上传 <gameId>/icon.png 到 OSS
# 3. 下载现有 manifest.json,用 jq 更新对应 game 条目,上传回去

set -euo pipefail

if [ "$#" -ne 2 ]; then
    echo "用法: $0 <gameId> <version>"
    exit 1
fi

GAME_ID=$1
VERSION=$2
ROOT=$(cd "$(dirname "$0")/.." && pwd)
DIST=${ROOT}/dist/${GAME_ID}-v${VERSION}.zip

OSS_BUCKET=cz-rn-bundle
OSS_PREFIX=oss://${OSS_BUCKET}/games
OSS_URL_BASE=https://${OSS_BUCKET}.oss-cn-hangzhou.aliyuncs.com/games

if [ ! -f "${DIST}" ]; then
    echo "找不到 ${DIST},先 ./scripts/build.sh ${GAME_ID} ${VERSION}"
    exit 1
fi

SHA256=$(shasum -a 256 ${DIST} | awk '{print $1}')
SIZE=$(wc -c < ${DIST} | tr -d ' ')

echo "📤 上传 zip..."
ossutil cp ${DIST} ${OSS_PREFIX}/${GAME_ID}/${GAME_ID}-v${VERSION}.zip
echo "📤 上传 icon..."
ossutil cp ${ROOT}/${GAME_ID}/icon.png ${OSS_PREFIX}/${GAME_ID}/icon.png

echo "📥 拉取现有 manifest.json..."
TMP_MANIFEST=$(mktemp)
ossutil cp ${OSS_PREFIX}/manifest.json ${TMP_MANIFEST}

echo "🔧 更新 manifest 内 ${GAME_ID} 的 version/url/sha256/size..."
NEW_MANIFEST=$(mktemp)
jq --arg id "${GAME_ID}" \
   --arg ver "${VERSION}" \
   --arg url "${OSS_URL_BASE}/${GAME_ID}/${GAME_ID}-v${VERSION}.zip" \
   --arg sha "${SHA256}" \
   --argjson size "${SIZE}" \
   --arg updated "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
'
  .updatedAt = $updated
  | (.games[] | select(.id == $id))
    |= (.version = $ver | .url = $url | .sha256 = $sha | .size = $size)
' ${TMP_MANIFEST} > ${NEW_MANIFEST}

echo "📤 回传 manifest.json..."
ossutil cp ${NEW_MANIFEST} ${OSS_PREFIX}/manifest.json --force

rm -f ${TMP_MANIFEST} ${NEW_MANIFEST}
echo "✅ ${GAME_ID} v${VERSION} 上线完成"
```

- [ ] **Step 2: 加权限 + 装 jq(如果没装)**

```bash
chmod +x /Users/carlos/HelloRN/WeChatGames/scripts/upload.sh
brew install jq  # 如果没装
```

- [ ] **Step 3: 跑一次更新 2048(模拟升级,version 改 1.1)**

修改 `WeChatGames/2048/main.js` 加点小改动(比如改顶部标题文字),然后:

```bash
cd /Users/carlos/HelloRN/WeChatGames
./scripts/build.sh 2048 1.1
./scripts/upload.sh 2048 1.1
```

OSS 上 manifest.json 应自动更新到 v1.1。

- [ ] **Step 4: app 验证升级**

⌘R 重启 app:
- 进游戏中心 → 2048 卡片显示"22K"(新 size)
- 点击 → 下载 v1.1 → 进入新版游戏(应看到改过的文字)

- [ ] **Step 5: 注:此 commit 在 WeChatGames 仓库**

如果 WeChatGames 没入 git,无 commit。否则 `cd WeChatGames && git add scripts/upload.sh && git commit -m "feat: upload.sh 自动化 manifest 更新"`。

---

### Task 24: README + Demo 录制

**Files:**
- Modify: `README.md`(项目根 — 加 GameModule 章节)

- [ ] **Step 1: 项目 README 加 GameModule 章节**

在 `README.md` 顶部(或合适位置)加:

```markdown
## 🎮 游戏中心(WebView + OSS 远程下发)

模拟器进入"发现" → "游戏",看到 H5 大厅(内置)+ WebView 加载 OSS 下载的游戏(2048 / 俄罗斯方块 / 记忆翻牌)。

### 架构亮点
- 大厅 H5 内置随 app 发版,游戏 H5 走 OSS 远程下载
- GameBundleManager 类 RNBundleManager 思路:manifest + SHA256 + 多版本 + 灰度 + 回滚
- 大厅 → 游戏走 URL scheme 拦截(无 JS Bridge,纯 web 自闭环)
- 3 款游戏全部 Claude/Codex AI 生成

### 设计 / 实施文档
- 设计:`docs/superpowers/specs/2026-05-30-game-module-design.md`
- 实施:`docs/superpowers/plans/2026-05-30-game-module.md`

### 游戏 H5 源码
- 独立工程:`HelloRN/WeChatGames/`(跟 iOS 工程平级)
- 构建:`./scripts/build.sh <gameId> <version>`
- 上线:`./scripts/upload.sh <gameId> <version>`(OSS 上传 + manifest 自动更新)
```

- [ ] **Step 2: 录制 Demo 视频(简历用)**

模拟器录屏 30s:
1. 启动 app → Discover → 点击"游戏"
2. 大厅显示 3 张游戏卡片 + 角标 + 文件大小
3. 点击 2048 → 下载中… → 进入游戏 → 玩两步
4. 返回大厅 → 卡片角标变 "已下载"
5. 退到 Discover → 再进游戏 → 秒开

存到 `docs/superpowers/demos/game-module-demo.mp4`(可选)。

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: 项目 README 加游戏中心章节"
```

---

### Task 25: Phase 3 最终验证

- [ ] **Step 1: 完整跑一遍流程(灰度 + 回滚)**

**灰度测试**:
- 把 OSS manifest 里 2048 的 `grayscale.percentage` 改为 50
- 杀进程重启 app → 多次重启,大约一半次数大厅看不到 2048(deviceId hash 决定,但 deviceId 不变所以多次重启一致)
- 把 percentage 改回 100,杀进程重启 → 2048 总是显示

**回滚测试**:
- 修改 OSS manifest 把 2048 的 sha256 改为错的(模拟"新版有问题")
- 杀进程重启 → 进 2048 → 下载失败但有本地 v1.0 cache → 自动回退到老版本
- console 应有 `[Game] 回退到本地版本 2048 v1.0`

- [ ] **Step 2: 跑所有单元测试**

```bash
xcodebuild test -workspace WeChatSwift.xcworkspace -scheme WeChatSwift \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20
```

Expected: GameModule 测试全 pass(GameManifestTests + GameBundleStorageTests),其他模块测试不被破坏。

- [ ] **Step 3: Phase 3 milestone commit**

```bash
git commit --allow-empty -m "milestone(game): Phase 3 完成 — 灰度 + 回滚 + README + Demo"
```

---

## 完成

**总任务数:** 25 个 task,分三个 Phase
**预估总工时:** 约 1.5-2 周(P1 ~1 周 + P2 ~3-5 天 + P3 ~2-3 天)

按顺序执行,每个 task 完成后 commit。可在 task 末尾用 `subagent-driven-development` 或 `executing-plans` 跟踪进度。
