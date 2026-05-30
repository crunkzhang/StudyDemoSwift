# IM 2.0 重构实施计划 (Phase 1+2+3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 spec (`docs/superpowers/specs/2026-05-30-im2-refactor-design.md`) 中 A 档骨架级 IM 2.0 重构落地到 WeChatSwift,实现"分层 + Sync 主线 + 会话列表可插拔排序 + 详情页基础收发"完整可演示骨架。

**Architecture:** WCIMSDK (Platform Pod) 提供 Service+DB+广播基础设施,ChatModule (Business Pod) 按 MVVM 划分 SessionList/ChatDetail 两页面,数据走 Sync → 事务落库 → DBChangeStream → Logic → @Published → DiffableDataSource 单向流。

**Tech Stack:** Swift 5、UIKit、WCDB.swift、Combine、Swift Concurrency (async/await)、SnapKit、CocoaPods (use_frameworks! :linkage => :static)、XcodeGen、UITableViewDiffableDataSource (iOS 15+)。

---

## File Structure

### 新建 / 修改文件清单

```
Modules/Platform/WCIMSDK/                              ← 新建 Pod (P1)
├── WCIMSDK.podspec                                    [P1]
├── WCIMSDK.swift                                      [P1]  入口 namespace
├── Model/
│   ├── SessionModel.swift                             [P1]  WCDB TableCodable
│   └── MessageModel.swift                             [P2]  WCDB TableCodable
├── DB/
│   ├── DBPaths.swift                                  [P1]  userId 物理库路径
│   ├── DBChangeStream.swift                           [P1]  PassthroughSubject + 事件
│   ├── SessionDB.swift                                [P1]  WCDB 操作封装
│   ├── MessageTableNameRegistry.swift                 [P1]  SHA1 hash + 防注入
│   └── MessageDB.swift                                [P2]  动态建表 + upsert
├── Service/
│   ├── SeqIdManager.swift                             [P1]  串行推进 + 持久化
│   ├── SyncService.swift                              [P1]  Mock fetchIncremental
│   └── PushService.swift                              [P2]  Mock upload + 推送
├── SendQueueManager.swift                             [P2]  [sessionId: 串行队列]
└── WCIMSDKTests/                                      [test_spec]
    ├── MessageTableNameRegistryTests.swift            [P1]
    ├── SeqIdManagerTests.swift                        [P1]
    └── SendQueueManagerTests.swift                    [P2]

Modules/Business/ChatModule/                           ← 重构 (P1)
├── ChatModule.podspec                                 [修改]  加 WCIMSDK 依赖
├── ChatModule.swift                                   [修改 P2]  registerRoutes
├── SessionList/                                       ← 新建 (P1)
│   ├── VC/SessionListViewController.swift             [P1]
│   ├── Logic/
│   │   ├── SessionListLogic.swift                     [P1]
│   │   ├── SessionDBObserver.swift                    [P1]
│   │   ├── SessionDBHandler.swift                     [P1]
│   │   └── SortRule/
│   │       ├── SortRule.swift                         [P1]  protocol + Chain
│   │       ├── PinnedSortRule.swift                   [P1]
│   │       ├── TimestampSortRule.swift                [P1]
│   │       ├── DraftSortRule.swift                    [P3]
│   │       └── UnreadFirstSortRule.swift              [P3]
│   ├── View/SessionListCell.swift                     [P1]
│   └── Model/SessionCellModel.swift                   [P1]
├── ChatDetail/                                        ← 新建 (P2)
│   ├── VC/ChatDetailViewController.swift              [P2]
│   ├── Logic/
│   │   ├── ChatDetailLogic.swift                      [P2]
│   │   ├── MessageDBObserver.swift                    [P2]
│   │   ├── MessageDBHandler.swift                     [P2]
│   │   ├── SendMsgHandler.swift                       [P2]
│   │   └── MessageRenderCache.swift                   [P3]
│   ├── View/
│   │   ├── ChatInputBar.swift                         [P2]
│   │   └── Cells/
│   │       ├── BaseMessageCell.swift                  [P2]
│   │       └── TextMessageCell.swift                  [P2]
│   └── Model/MessageCellModel.swift                   [P2]
└── ChatModuleTests/                                   [test_spec]
    ├── SortRuleChainTests.swift                       [P1]
    └── SessionCellModelTests.swift                    [P1]

❌ 删除:
Modules/Business/ChatModule/Chat/ChatViewController.swift     [P1]
Modules/Business/ChatModule/Chat/ChatListCell.swift           [P1]
Modules/Business/ChatModule/Models/ChatConversation.swift     [P1]
Modules/Business/ChatModule/Models/MockChatData.swift         [P1]

修改主工程:
Podfile                                                [P1]  加 WCIMSDK + WCDB.swift
project.yml                                            [P1]  加 WeChatSwiftTests target
WeChatSwift/MainTabBarController.swift                 [P1]  替换 ChatVC → SessionListVC
WeChatSwift/AppDelegate.swift                          [P1]  初始化 WCIMSDK
Modules/WeChatKit/WeChatRouter/Routes.swift            [P2]  chatDetail 改原生 URL
```

---

## 验证策略

由于 iOS 项目特性,采用混合验证:

- **纯逻辑类任务** (SortRuleChain, SeqIdManager, MessageTableNameRegistry, SessionCellModel, SendQueueManager, MessageRenderCache) — 严格 TDD,XCTest,跑通才 commit
- **DB / Service / Logic 集成类** — 在 AppDelegate 加临时自检入口 + 控制台日志验证
- **UI 类** — 每个 Phase 末尾运行 app 手动验证 + 截图/录屏入 docs

### 关于 `xcodebuild test -only-testing` 命令

各任务里的 `-only-testing:WCIMSDK-Unit-Tests/<TestClass>` 与 `-only-testing:ChatModule-Unit-Tests/<TestClass>` 是 CocoaPods test_spec 1.10+ 生成的 bundle 命名约定。如果你的 CocoaPods 版本生成的 test bundle 命名不同(可通过 `xcodebuild -workspace WeChatSwift.xcworkspace -list` 查看实际 scheme/target 名)或命令报"Could not find test bundle"错误,有两种 fallback:

1. **直接 Xcode UI 跑** — ⌘U 跑全部测试,或点测试方法旁边的菱形图标跑单个
2. **跑整体 test action** — `xcodebuild test -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15'`(跑所有测试,看输出筛选)

---

# Phase 1 · Session List End-to-End (~1 周)

---

### Task 1: 给主工程加 WeChatSwiftTests 测试 Target

**Files:**
- Modify: `project.yml`
- Create: `WeChatSwiftTests/WeChatSwiftTests.swift` (placeholder)

- [ ] **Step 1: 修改 project.yml 加入 test target**

修改 `project.yml`,在 `targets:` 下追加:

```yaml
  WeChatSwiftTests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - WeChatSwiftTests
    dependencies:
      - target: WeChatSwift
    settings:
      base:
        BUNDLE_LOADER: $(TEST_HOST)
        TEST_HOST: $(BUILT_PRODUCTS_DIR)/WeChatSwift.app/WeChatSwift
        PRODUCT_BUNDLE_IDENTIFIER: com.study.wcSwiftTests
        CODE_SIGN_STYLE: Automatic
        DEVELOPMENT_TEAM: 2DAFKPU228
```

在 `schemes.WeChatSwift.test:` 节点(若无则新建)添加:

```yaml
schemes:
  WeChatSwift:
    build:
      targets:
        WeChatSwift: all
        WeChatSwiftTests: [test]
    run:
      config: Debug
    test:
      config: Debug
      targets:
        - WeChatSwiftTests
    archive:
      config: Release
```

- [ ] **Step 2: 创建占位测试文件**

```swift
// WeChatSwiftTests/WeChatSwiftTests.swift
import XCTest

final class WeChatSwiftTests: XCTestCase {
    func test_sanity() {
        XCTAssertEqual(1 + 1, 2)
    }
}
```

- [ ] **Step 3: 重新生成 xcodeproj**

```bash
cd /Users/carlos/HelloRN/WeChatSwift && xcodegen generate
```

Expected: `Created project at WeChatSwift.xcodeproj`

- [ ] **Step 4: 跑测试验证 target 可用**

在 Xcode 里 ⌘U 跑测试,或命令行:

```bash
xcodebuild test -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -20
```

Expected: `Test Suite 'WeChatSwiftTests' passed`

- [ ] **Step 5: Commit**

```bash
git add project.yml WeChatSwiftTests/ WeChatSwift.xcodeproj
git commit -m "chore: add WeChatSwiftTests target for unit tests"
```

---

### Task 2: 创建 WCIMSDK Pod 骨架

**Files:**
- Create: `Modules/Platform/WCIMSDK/WCIMSDK.podspec`
- Create: `Modules/Platform/WCIMSDK/WCIMSDK.swift`
- Modify: `Podfile`

- [ ] **Step 1: 创建 podspec**

```ruby
# Modules/Platform/WCIMSDK/WCIMSDK.podspec
Pod::Spec.new do |s|
  s.name             = 'WCIMSDK'
  s.version          = '1.0.0'
  s.summary          = 'IM 通用基础设施 — Service + DB + 变更广播'
  s.description      = 'Platform 层 IM SDK,提供 Sync/Push 服务、WCDB 落库、DBChangeStream 变更广播'
  s.homepage         = 'https://github.com/nicedayzhu/WeChatSwift'
  s.license          = { :type => 'MIT' }
  s.author           = { 'nicedayzhu' => 'nicedayzhu@example.com' }
  s.source           = { :git => '', :tag => s.version.to_s }

  s.ios.deployment_target = '15.1'
  s.swift_version = '5.0'

  s.source_files = '**/*.swift'
  s.exclude_files = 'WCIMSDKTests/**/*'

  s.frameworks = 'Foundation', 'UIKit'

  s.dependency 'WCDB.swift'

  s.test_spec 'WCIMSDKTests' do |ts|
    ts.source_files = 'WCIMSDKTests/**/*.swift'
    ts.frameworks = 'XCTest'
  end
end
```

- [ ] **Step 2: 创建入口文件**

```swift
// Modules/Platform/WCIMSDK/WCIMSDK.swift
import Foundation

public enum WCIMSDK {
    /// 当前登录用户 ID(切账号时调用 setup 重新初始化)
    public private(set) static var currentUserId: String = ""

    /// SDK 初始化入口 — 必须在使用任何 DB / Service 前调用
    public static func setup(userId: String) {
        currentUserId = userId
        // 后续 Task 会在此处初始化 DB / Service
    }
}
```

- [ ] **Step 3: Podfile 加入新 Pod**

修改 `Podfile`,在 `# ── Platform 层 ──` 注释下追加:

```ruby
  pod 'WCIMSDK',        :path => 'Modules/Platform/WCIMSDK'
```

并在 `# ── Foundation 层 ──` 之前确保有 Platform 子目录(可能要新建 `Modules/Platform/` 目录,把现有 Modules/WeChatKit 概念上视为 Platform)。

注意:**新 pod 路径是 `Modules/Platform/WCIMSDK`**,需要先创建目录:

```bash
mkdir -p /Users/carlos/HelloRN/WeChatSwift/Modules/Platform/WCIMSDK
```

- [ ] **Step 4: 验证 pod install 通过**

```bash
cd /Users/carlos/HelloRN/WeChatSwift && pod install 2>&1 | tail -10
```

Expected: `Pod installation complete!` 包含 `WCIMSDK` 和 `WCDB.swift`

- [ ] **Step 5: 编译验证**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -5
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add Modules/Platform/WCIMSDK Podfile Podfile.lock Pods
git commit -m "feat(wcimsdk): 创建 Pod 骨架 + 加入 WCDB.swift 依赖"
```

---

### Task 3: DBPaths — 按 userId 切物理库路径

**Files:**
- Create: `Modules/Platform/WCIMSDK/DB/DBPaths.swift`

- [ ] **Step 1: 实现 DBPaths**

```swift
// Modules/Platform/WCIMSDK/DB/DBPaths.swift
import Foundation

public enum DBPaths {
    /// 当前用户的 IM 数据目录
    /// 路径:Documents/IM/{userId}/
    public static func userIMDirectory(userId: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("IM/\(userId)", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    public static func sessionDBPath(userId: String) -> String {
        userIMDirectory(userId: userId).appendingPathComponent("session.db").path
    }

    public static func messageDBPath(userId: String) -> String {
        userIMDirectory(userId: userId).appendingPathComponent("message.db").path
    }
}
```

- [ ] **Step 2: 编译验证**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Modules/Platform/WCIMSDK/DB/DBPaths.swift
git commit -m "feat(wcimsdk): DBPaths 按 userId 隔离物理库路径"
```

---

### Task 4: SessionModel — WCDB TableCodable

**Files:**
- Create: `Modules/Platform/WCIMSDK/Model/SessionModel.swift`

- [ ] **Step 1: 实现 SessionModel**

```swift
// Modules/Platform/WCIMSDK/Model/SessionModel.swift
import Foundation
import WCDBSwift

public final class SessionModel: TableCodable {
    public var sessionId: String = ""
    public var contactName: String = ""
    public var avatarURL: String?
    public var lastMsgId: String?
    public var lastMsgPreview: String?
    public var lastTimestamp: Int64 = 0
    public var unreadCount: Int = 0
    public var isPinned: Bool = false
    public var draft: String?
    public var extraJSON: String?

    public init() {}

    public enum CodingKeys: String, CodingTableKey {
        public typealias Root = SessionModel
        case sessionId, contactName, avatarURL
        case lastMsgId, lastMsgPreview, lastTimestamp
        case unreadCount, isPinned, draft, extraJSON

        public static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(sessionId, isPrimary: true)
            BindIndex(lastTimestamp, namedWith: "_lastTimestamp")
            BindIndex(isPinned, namedWith: "_isPinned")
        }
    }
}
```

- [ ] **Step 2: 编译验证**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
```

Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add Modules/Platform/WCIMSDK/Model/SessionModel.swift
git commit -m "feat(wcimsdk): SessionModel WCDB TableCodable"
```

---

### Task 5: DBChangeStream — PassthroughSubject + 事件类型

**Files:**
- Create: `Modules/Platform/WCIMSDK/DB/DBChangeStream.swift`

- [ ] **Step 1: 实现 DBChangeStream**

```swift
// Modules/Platform/WCIMSDK/DB/DBChangeStream.swift
import Foundation
import Combine

public enum SessionChangeEvent {
    case insert([String])    // sessionIds
    case update([String])
    case delete([String])
}

public enum MessageChangeEvent {
    case insert(sessionId: String, messages: [MessageEntityRef])
    case update(sessionId: String, messages: [MessageEntityRef])
    case delete(sessionId: String, localMsgIds: [String])
}

/// 占位:Phase 2 MessageModel 落地后会替换为真 MessageModel
/// 现在用 protocol 解决类型循环
public protocol MessageEntityRef {
    var localMsgId: String { get }
    var sessionId: String { get }
}

public final class DBChangeStream {
    public static let shared = DBChangeStream()
    private init() {}

    private let sessionSubject = PassthroughSubject<SessionChangeEvent, Never>()
    private let messageSubject = PassthroughSubject<(sessionId: String, event: MessageChangeEvent), Never>()

    public var sessionsPublisher: AnyPublisher<SessionChangeEvent, Never> {
        sessionSubject.eraseToAnyPublisher()
    }

    /// 按 sessionId 过滤的消息变更流(每个 ChatDetailLogic 各订各的)
    public func messagesPublisher(of sessionId: String) -> AnyPublisher<MessageChangeEvent, Never> {
        messageSubject
            .filter { $0.sessionId == sessionId }
            .map { $0.event }
            .eraseToAnyPublisher()
    }

    // MARK: - Internal: DB 层在事务 commit 后调用

    public func publish(session event: SessionChangeEvent) {
        sessionSubject.send(event)
    }

    public func publish(message event: MessageChangeEvent, sessionId: String) {
        messageSubject.send((sessionId, event))
    }
}
```

- [ ] **Step 2: 编译验证 + Commit**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
git add Modules/Platform/WCIMSDK/DB/DBChangeStream.swift
git commit -m "feat(wcimsdk): DBChangeStream 写入侧主动广播变更"
```

Expected: `BUILD SUCCEEDED`

---

### Task 6: MessageTableNameRegistry — SHA1 hash + 防注入 (TDD)

**Files:**
- Create: `Modules/Platform/WCIMSDK/DB/MessageTableNameRegistry.swift`
- Test: `Modules/Platform/WCIMSDK/WCIMSDKTests/MessageTableNameRegistryTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
// Modules/Platform/WCIMSDK/WCIMSDKTests/MessageTableNameRegistryTests.swift
import XCTest
@testable import WCIMSDK

final class MessageTableNameRegistryTests: XCTestCase {
    var registry: MessageTableNameRegistry!

    override func setUp() {
        super.setUp()
        registry = MessageTableNameRegistry()
    }

    func test_tableName_isDeterministic() {
        let a = registry.tableName(for: "u123-u456")
        let b = registry.tableName(for: "u123-u456")
        XCTAssertEqual(a, b)
    }

    func test_tableName_hasMessagePrefix() {
        let name = registry.tableName(for: "u123-u456")
        XCTAssertTrue(name.hasPrefix("message_"))
    }

    func test_tableName_isFixedLength_24chars() {
        let name = registry.tableName(for: "u123-u456")
        XCTAssertEqual(name.count, 24)  // "message_" (8) + 16 hex chars
    }

    func test_tableName_onlyAllowsSafeChars() {
        let name = registry.tableName(for: "u'; DROP TABLE; --")
        let safe = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        XCTAssertNil(name.rangeOfCharacter(from: safe.inverted))
    }

    func test_differentSessions_produceDifferentNames() {
        let a = registry.tableName(for: "u1-u2")
        let b = registry.tableName(for: "u1-u3")
        XCTAssertNotEqual(a, b)
    }
}
```

- [ ] **Step 2: 跑测试验证失败**

```bash
xcodebuild test -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:WCIMSDK-Unit-Tests/MessageTableNameRegistryTests 2>&1 | tail -10
```

Expected: 编译失败,提示 `Cannot find 'MessageTableNameRegistry' in scope`

- [ ] **Step 3: 实现 MessageTableNameRegistry**

```swift
// Modules/Platform/WCIMSDK/DB/MessageTableNameRegistry.swift
import Foundation
import CommonCrypto

public final class MessageTableNameRegistry {

    private var cache: [String: String] = [:]
    private let lock = NSLock()

    public init() {}

    /// 表名 = "message_" + SHA1(sessionId).prefix(16)
    /// 长度固定 24 字符,只含 [a-z0-9_],绝对防注入
    public func tableName(for sessionId: String) -> String {
        lock.lock(); defer { lock.unlock() }
        if let cached = cache[sessionId] { return cached }
        let name = "message_" + Self.sha1Prefix16(sessionId)
        cache[sessionId] = name
        return name
    }

    private static func sha1Prefix16(_ input: String) -> String {
        let data = Data(input.utf8)
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes { buf in
            _ = CC_SHA1(buf.baseAddress, CC_LONG(data.count), &digest)
        }
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return String(hex.prefix(16))
    }
}
```

- [ ] **Step 4: 跑测试验证通过**

```bash
xcodebuild test -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:WCIMSDK-Unit-Tests/MessageTableNameRegistryTests 2>&1 | tail -5
```

Expected: `Test Suite 'MessageTableNameRegistryTests' passed`

- [ ] **Step 5: Commit**

```bash
git add Modules/Platform/WCIMSDK/DB/MessageTableNameRegistry.swift Modules/Platform/WCIMSDK/WCIMSDKTests/
git commit -m "feat(wcimsdk): MessageTableNameRegistry SHA1 截取 + 防注入"
```

---

### Task 7: SeqIdManager — 串行推进 + 持久化 (TDD)

**Files:**
- Create: `Modules/Platform/WCIMSDK/Service/SeqIdManager.swift`
- Test: `Modules/Platform/WCIMSDK/WCIMSDKTests/SeqIdManagerTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
// Modules/Platform/WCIMSDK/WCIMSDKTests/SeqIdManagerTests.swift
import XCTest
@testable import WCIMSDK

final class SeqIdManagerTests: XCTestCase {
    var mgr: SeqIdManager!
    let key = "im.seqId.test_user"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: key)
        mgr = SeqIdManager(userId: "test_user")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: key)
        super.tearDown()
    }

    func test_initialSeqIdIsZero() {
        XCTAssertEqual(mgr.currentSeqId, 0)
    }

    func test_advance_increasesValue() {
        mgr.advance(to: 100)
        XCTAssertEqual(mgr.currentSeqId, 100)
    }

    func test_advance_doesNotGoBackwards() {
        mgr.advance(to: 100)
        mgr.advance(to: 50)
        XCTAssertEqual(mgr.currentSeqId, 100)
    }

    func test_advance_persistsToUserDefaults() {
        mgr.advance(to: 200)
        let mgr2 = SeqIdManager(userId: "test_user")
        XCTAssertEqual(mgr2.currentSeqId, 200)
    }

    func test_concurrentAdvance_neverRegresses() {
        let g = DispatchGroup()
        for i in 1...100 {
            g.enter()
            DispatchQueue.global().async {
                self.mgr.advance(to: Int64(i))
                g.leave()
            }
        }
        g.wait()
        XCTAssertGreaterThanOrEqual(mgr.currentSeqId, 1)
        XCTAssertLessThanOrEqual(mgr.currentSeqId, 100)
    }
}
```

- [ ] **Step 2: 跑测试验证失败**

```bash
xcodebuild test -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:WCIMSDK-Unit-Tests/SeqIdManagerTests 2>&1 | tail -5
```

Expected: `Cannot find 'SeqIdManager' in scope`

- [ ] **Step 3: 实现 SeqIdManager**

```swift
// Modules/Platform/WCIMSDK/Service/SeqIdManager.swift
import Foundation

public final class SeqIdManager {
    private let key: String
    private let queue = DispatchQueue(label: "im.seqId.advance")
    private(set) public var currentSeqId: Int64

    public init(userId: String) {
        self.key = "im.seqId.\(userId)"
        self.currentSeqId = Int64(UserDefaults.standard.integer(forKey: key))
    }

    public func advance(to seqId: Int64) {
        queue.sync {
            guard seqId > currentSeqId else { return }
            currentSeqId = seqId
            UserDefaults.standard.set(seqId, forKey: key)
        }
    }
}
```

- [ ] **Step 4: 跑测试验证通过**

```bash
xcodebuild test -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:WCIMSDK-Unit-Tests/SeqIdManagerTests 2>&1 | tail -5
```

Expected: `Test Suite 'SeqIdManagerTests' passed`

- [ ] **Step 5: Commit**

```bash
git add Modules/Platform/WCIMSDK/Service/SeqIdManager.swift Modules/Platform/WCIMSDK/WCIMSDKTests/SeqIdManagerTests.swift
git commit -m "feat(wcimsdk): SeqIdManager 串行推进 + UserDefaults 持久化"
```

---

### Task 8: SessionDB — WCDB 操作封装

**Files:**
- Create: `Modules/Platform/WCIMSDK/DB/SessionDB.swift`
- Modify: `Modules/Platform/WCIMSDK/WCIMSDK.swift` (在 setup 中初始化)

- [ ] **Step 1: 实现 SessionDB**

```swift
// Modules/Platform/WCIMSDK/DB/SessionDB.swift
import Foundation
import WCDBSwift

public final class SessionDB {
    private let db: Database
    private let table = "sessions"

    public init(userId: String) {
        let path = DBPaths.sessionDBPath(userId: userId)
        self.db = Database(at: path)
        try? db.create(table: table, of: SessionModel.self)
    }

    // MARK: - 读

    public func fetchAll() -> [SessionModel] {
        (try? db.getObjects(fromTable: table)) ?? []
    }

    public func fetch(sessionIds: [String]) -> [SessionModel] {
        guard !sessionIds.isEmpty else { return [] }
        return (try? db.getObjects(
            fromTable: table,
            where: SessionModel.Properties.sessionId.in(sessionIds)
        )) ?? []
    }

    // MARK: - 写(供 SyncService 在事务内调用)

    public func upsert(_ sessions: [SessionModel]) throws {
        try db.insertOrReplace(sessions, intoTable: table)
    }

    public func delete(sessionIds: [String]) throws {
        try db.delete(
            fromTable: table,
            where: SessionModel.Properties.sessionId.in(sessionIds)
        )
    }

    // MARK: - 事务

    public func runTransaction(_ block: () throws -> Void) throws {
        try db.run(transaction: { _ in
            try block()
        })
    }
}
```

- [ ] **Step 2: 修改 WCIMSDK.swift 初始化**

```swift
// Modules/Platform/WCIMSDK/WCIMSDK.swift
import Foundation

public enum WCIMSDK {
    public private(set) static var currentUserId: String = ""
    public private(set) static var sessionDB: SessionDB?
    public private(set) static var seqIdManager: SeqIdManager?

    public static func setup(userId: String) {
        currentUserId = userId
        sessionDB = SessionDB(userId: userId)
        seqIdManager = SeqIdManager(userId: userId)
    }
}
```

- [ ] **Step 3: 编译验证 + Commit**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
git add Modules/Platform/WCIMSDK/DB/SessionDB.swift Modules/Platform/WCIMSDK/WCIMSDK.swift
git commit -m "feat(wcimsdk): SessionDB CRUD 封装 + SDK 入口初始化"
```

Expected: `BUILD SUCCEEDED`

---

### Task 9: MockSyncService — 吐 100 条假会话变更

**Files:**
- Create: `Modules/Platform/WCIMSDK/Service/SyncService.swift`

- [ ] **Step 1: 实现 SyncService**

```swift
// Modules/Platform/WCIMSDK/Service/SyncService.swift
import Foundation

public protocol SyncServiceProtocol {
    func fetchIncremental(after seqId: Int64) async throws -> SyncBatch
}

public struct SyncBatch {
    public let sessions: [SessionModel]      // 本次同步涉及的会话(待 upsert)
    public let messages: [MessageEntityRef]  // 预留 Phase 2 用,Phase 1 空数组
    public let maxSeqId: Int64

    public init(sessions: [SessionModel], messages: [MessageEntityRef], maxSeqId: Int64) {
        self.sessions = sessions
        self.messages = messages
        self.maxSeqId = maxSeqId
    }
}

public final class MockSyncService: SyncServiceProtocol {
    public init() {}

    public func fetchIncremental(after seqId: Int64) async throws -> SyncBatch {
        try await Task.sleep(nanoseconds: 200_000_000)  // 模拟网络延迟 200ms

        // 首次同步:吐 100 条假会话
        if seqId == 0 {
            return SyncBatch(
                sessions: Self.generateMockSessions(count: 100),
                messages: [],
                maxSeqId: 100
            )
        }

        // 增量:每次随机更新 1~3 条会话
        let updateCount = Int.random(in: 1...3)
        let sessions: [SessionModel] = (0..<updateCount).map { _ in
            let idx = Int.random(in: 0..<100)
            return Self.makeSession(index: idx, baseTimestamp: Int64(Date().timeIntervalSince1970))
        }
        return SyncBatch(sessions: sessions, messages: [], maxSeqId: seqId + Int64(updateCount))
    }

    // MARK: - Mock 数据

    private static let names = ["张伟", "王芳", "李娜", "刘洋", "陈静", "杨帆", "赵磊", "黄丽", "周杰", "吴敏"]
    private static let messages = ["你好", "在吗?", "[图片]", "今晚一起吃饭", "好的,收到", "[文件]", "晚安🌙", "明天见", "周末爬山", "刚到家"]

    public static func generateMockSessions(count: Int) -> [SessionModel] {
        let now = Int64(Date().timeIntervalSince1970)
        return (0..<count).map { i in
            makeSession(index: i, baseTimestamp: now - Int64(i * 600))
        }
    }

    private static func makeSession(index i: Int, baseTimestamp: Int64) -> SessionModel {
        let m = SessionModel()
        m.sessionId = "mock_session_\(i)"
        m.contactName = names[i % names.count] + "\(i)"
        m.lastMsgPreview = messages[i % messages.count]
        m.lastTimestamp = baseTimestamp
        m.unreadCount = i % 7 == 0 ? Int.random(in: 1...99) : 0
        m.isPinned = i < 3   // 前 3 个置顶
        return m
    }
}
```

- [ ] **Step 2: 编译验证 + Commit**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
git add Modules/Platform/WCIMSDK/Service/SyncService.swift
git commit -m "feat(wcimsdk): MockSyncService 模拟增量同步 + 100 条假会话"
```

Expected: `BUILD SUCCEEDED`

---

### Task 10: Sync 主线编排 — Service 拉取 → 事务落库 → 推进 → 广播

**Files:**
- Modify: `Modules/Platform/WCIMSDK/Service/SyncService.swift` (新增 SyncCoordinator)
- Modify: `Modules/Platform/WCIMSDK/WCIMSDK.swift`

- [ ] **Step 1: 新增 SyncCoordinator**

在 `SyncService.swift` 文件末尾追加:

```swift
public final class SyncCoordinator {
    private let service: SyncServiceProtocol
    private let sessionDB: SessionDB
    private let seqIdManager: SeqIdManager
    private let changeStream: DBChangeStream
    private var inFlight = false
    private let lock = NSLock()

    public init(service: SyncServiceProtocol, sessionDB: SessionDB,
                seqIdManager: SeqIdManager, changeStream: DBChangeStream = .shared) {
        self.service = service
        self.sessionDB = sessionDB
        self.seqIdManager = seqIdManager
        self.changeStream = changeStream
    }

    /// 触发一次增量同步(并发 sync 自动合并 → 只跑一次)
    public func triggerSync() async {
        lock.lock()
        if inFlight { lock.unlock(); return }
        inFlight = true
        lock.unlock()

        defer {
            lock.lock(); inFlight = false; lock.unlock()
        }

        do {
            let currentSeq = seqIdManager.currentSeqId
            let batch = try await service.fetchIncremental(after: currentSeq)
            try applyBatch(batch)
            seqIdManager.advance(to: batch.maxSeqId)
            print("[Sync] ✅ applied \(batch.sessions.count) sessions, advanced seqId → \(batch.maxSeqId)")
        } catch {
            print("[Sync] ❌ failed: \(error)")
        }
    }

    private func applyBatch(_ batch: SyncBatch) throws {
        guard !batch.sessions.isEmpty else { return }

        // 按 sessionId 分组聚合(同会话只 upsert 1 次)
        var grouped: [String: SessionModel] = [:]
        for s in batch.sessions { grouped[s.sessionId] = s }
        let toUpsert = Array(grouped.values)
        let sessionIds = Array(grouped.keys)

        // 区分 insert / update(查现有数据)
        let existing = Set(sessionDB.fetch(sessionIds: sessionIds).map { $0.sessionId })
        let insertedIds = sessionIds.filter { !existing.contains($0) }
        let updatedIds = sessionIds.filter { existing.contains($0) }

        try sessionDB.runTransaction {
            try sessionDB.upsert(toUpsert)
        }

        // 事务成功后才广播(事务失败抛错则不进这里)
        if !insertedIds.isEmpty { changeStream.publish(session: .insert(insertedIds)) }
        if !updatedIds.isEmpty  { changeStream.publish(session: .update(updatedIds)) }
    }
}
```

- [ ] **Step 2: WCIMSDK 入口暴露 SyncCoordinator**

```swift
// Modules/Platform/WCIMSDK/WCIMSDK.swift
import Foundation

public enum WCIMSDK {
    public private(set) static var currentUserId: String = ""
    public private(set) static var sessionDB: SessionDB?
    public private(set) static var seqIdManager: SeqIdManager?
    public private(set) static var syncCoordinator: SyncCoordinator?

    public static func setup(userId: String) {
        currentUserId = userId
        let db = SessionDB(userId: userId)
        let seq = SeqIdManager(userId: userId)
        sessionDB = db
        seqIdManager = seq
        syncCoordinator = SyncCoordinator(
            service: MockSyncService(),
            sessionDB: db,
            seqIdManager: seq
        )
    }
}
```

- [ ] **Step 3: 编译验证 + Commit**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
git add Modules/Platform/WCIMSDK/Service/SyncService.swift Modules/Platform/WCIMSDK/WCIMSDK.swift
git commit -m "feat(wcimsdk): SyncCoordinator 编排 Sync 主线 + 事务后广播"
```

Expected: `BUILD SUCCEEDED`

---

### Task 11: AppDelegate 集成 WCIMSDK.setup + 触发首次同步

**Files:**
- Modify: `WeChatSwift/AppDelegate.swift`

- [ ] **Step 1: 修改 AppDelegate**

替换现有 `application(_:didFinishLaunchingWithOptions:)` 中 `CatonMonitor.shared.start()` 之前的区段:

```swift
// WeChatSwift/AppDelegate.swift
import UIKit
import WeChatRN
import CatonMonitorKit
import WCIMSDK

class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        LaunchMetrics.mark("didFinishStart")

        // IM SDK 初始化(写死一个 mock userId)
        WCIMSDK.setup(userId: "mock_local_user")

        // 触发首次同步(异步)
        Task { await WCIMSDK.syncCoordinator?.triggerSync() }

        CatonMonitor.shared.start()
        RNFactoryManager.shared.setup()

        LaunchScheduler.shared.registerAll()
        LaunchScheduler.shared.start()

        LaunchMetrics.mark("didFinishEnd")
        LaunchMetrics.observeFirstFrame()
        return true
    }
    // ... 其他方法保持不变
}
```

- [ ] **Step 2: 启动 app 验证日志**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
```

然后在 Xcode 里 ⌘R 运行,观察 console 应有:
```
[Sync] ✅ applied 100 sessions, advanced seqId → 100
```

第二次启动应有:
```
[Sync] ✅ applied N sessions, advanced seqId → 10X  (增量小批量)
```

- [ ] **Step 3: Commit**

```bash
git add WeChatSwift/AppDelegate.swift
git commit -m "feat(app): AppDelegate 初始化 WCIMSDK + 启动后触发首次同步"
```

---

### Task 12: ChatModule 旧文件清理

**Files:**
- Delete: `Modules/Business/ChatModule/Chat/`
- Delete: `Modules/Business/ChatModule/Models/`

- [ ] **Step 1: 删除旧文件**

```bash
cd /Users/carlos/HelloRN/WeChatSwift
git rm -r Modules/Business/ChatModule/Chat
git rm -r Modules/Business/ChatModule/Models
```

- [ ] **Step 2: 临时改 MainTabBarController 让编译过**

修改 `WeChatSwift/MainTabBarController.swift`,临时把 `let chat = ChatViewController()` 改为占位:

```swift
let chat = UIViewController()
chat.view.backgroundColor = .white
chat.title = "微信 (重构中)"
```

- [ ] **Step 3: 编译验证**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add WeChatSwift/MainTabBarController.swift Modules/Business/ChatModule/
git commit -m "refactor(chat): 删除旧 ChatViewController + MockChatData,准备重构"
```

---

### Task 13: SessionCellModel — Hashable struct (TDD)

**Files:**
- Create: `Modules/Business/ChatModule/SessionList/Model/SessionCellModel.swift`
- Test: `Modules/Business/ChatModule/ChatModuleTests/SessionCellModelTests.swift`
- Modify: `Modules/Business/ChatModule/ChatModule.podspec` (加 test_spec)

- [ ] **Step 1: ChatModule.podspec 加 test_spec**

修改 `Modules/Business/ChatModule/ChatModule.podspec`,文件末尾 `end` 之前追加:

```ruby
  s.dependency 'WCIMSDK'

  s.exclude_files = 'ChatModuleTests/**/*'

  s.test_spec 'ChatModuleTests' do |ts|
    ts.source_files = 'ChatModuleTests/**/*.swift'
    ts.frameworks = 'XCTest'
  end
```

- [ ] **Step 2: 写失败测试**

```swift
// Modules/Business/ChatModule/ChatModuleTests/SessionCellModelTests.swift
import XCTest
@testable import ChatModule

final class SessionCellModelTests: XCTestCase {

    func makeModel(sessionId: String = "s1", name: String = "张三",
                   unread: Int = 0, pinned: Bool = false,
                   ts: Int64 = 100) -> SessionCellModel {
        SessionCellModel(
            sessionId: sessionId, contactName: name, avatarURL: nil,
            lastMsgPreview: "hi", formattedTime: "12:00",
            unreadCount: unread, isPinned: pinned, lastTimestamp: ts
        )
    }

    func test_hash_isStableForSameSessionId() {
        let a = makeModel(sessionId: "s1", name: "A")
        let b = makeModel(sessionId: "s1", name: "B")
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func test_equality_comparesAllDisplayFields() {
        let a = makeModel(name: "A", unread: 5)
        let b = makeModel(name: "A", unread: 5)
        XCTAssertEqual(a, b)
    }

    func test_inequality_whenUnreadCountChanges() {
        let a = makeModel(unread: 0)
        let b = makeModel(unread: 1)
        XCTAssertNotEqual(a, b)
    }
}
```

- [ ] **Step 3: 跑测试验证失败**

```bash
cd /Users/carlos/HelloRN/WeChatSwift && pod install 2>&1 | tail -5
xcodebuild test -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:ChatModule-Unit-Tests/SessionCellModelTests 2>&1 | tail -5
```

Expected: `Cannot find 'SessionCellModel' in scope`

- [ ] **Step 4: 实现 SessionCellModel**

```swift
// Modules/Business/ChatModule/SessionList/Model/SessionCellModel.swift
import Foundation

public struct SessionCellModel: Hashable {
    public let sessionId: String
    public let contactName: String
    public let avatarURL: String?
    public let lastMsgPreview: String
    public let formattedTime: String
    public let unreadCount: Int
    public let isPinned: Bool
    public let lastTimestamp: Int64

    public init(sessionId: String, contactName: String, avatarURL: String?,
                lastMsgPreview: String, formattedTime: String,
                unreadCount: Int, isPinned: Bool, lastTimestamp: Int64) {
        self.sessionId = sessionId
        self.contactName = contactName
        self.avatarURL = avatarURL
        self.lastMsgPreview = lastMsgPreview
        self.formattedTime = formattedTime
        self.unreadCount = unreadCount
        self.isPinned = isPinned
        self.lastTimestamp = lastTimestamp
    }

    public func hash(into h: inout Hasher) {
        h.combine(sessionId)
    }

    public static func == (l: Self, r: Self) -> Bool {
        l.sessionId == r.sessionId
            && l.contactName == r.contactName
            && l.avatarURL == r.avatarURL
            && l.lastMsgPreview == r.lastMsgPreview
            && l.formattedTime == r.formattedTime
            && l.unreadCount == r.unreadCount
            && l.isPinned == r.isPinned
            && l.lastTimestamp == r.lastTimestamp
    }
}
```

- [ ] **Step 5: 跑测试验证通过**

```bash
xcodebuild test -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:ChatModule-Unit-Tests/SessionCellModelTests 2>&1 | tail -5
```

Expected: `Test Suite 'SessionCellModelTests' passed`

- [ ] **Step 6: Commit**

```bash
git add Modules/Business/ChatModule
git commit -m "feat(chat): SessionCellModel Hashable + 测试覆盖 hash/equality"
```

---

### Task 14: SortRule protocol + SortRuleChain (TDD)

**Files:**
- Create: `Modules/Business/ChatModule/SessionList/Logic/SortRule/SortRule.swift`
- Test: `Modules/Business/ChatModule/ChatModuleTests/SortRuleChainTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
// Modules/Business/ChatModule/ChatModuleTests/SortRuleChainTests.swift
import XCTest
@testable import ChatModule

final class SortRuleChainTests: XCTestCase {

    // 测试用规则:按 unreadCount 倒序(高在前)
    struct UnreadRule: SortRule {
        func compare(_ l: SessionCellModel, _ r: SessionCellModel) -> ComparisonResult {
            if l.unreadCount == r.unreadCount { return .orderedSame }
            return l.unreadCount > r.unreadCount ? .orderedAscending : .orderedDescending
        }
    }

    struct AlphaRule: SortRule {
        func compare(_ l: SessionCellModel, _ r: SessionCellModel) -> ComparisonResult {
            (l.contactName as NSString).compare(r.contactName)
        }
    }

    private func m(_ id: String, name: String = "x", unread: Int = 0) -> SessionCellModel {
        SessionCellModel(sessionId: id, contactName: name, avatarURL: nil,
                         lastMsgPreview: "", formattedTime: "",
                         unreadCount: unread, isPinned: false, lastTimestamp: 0)
    }

    func test_singleRule_sortsCorrectly() {
        let chain = SortRuleChain(rules: [UnreadRule()])
        let result = chain.sort([m("a", unread: 1), m("b", unread: 5), m("c", unread: 3)])
        XCTAssertEqual(result.map(\.sessionId), ["b", "c", "a"])
    }

    func test_chainFallsThrough_whenFirstRuleReturnsSame() {
        let chain = SortRuleChain(rules: [UnreadRule(), AlphaRule()])
        // unread 都相同 → 走第二条 alpha 排序
        let result = chain.sort([m("1", name: "C"), m("2", name: "A"), m("3", name: "B")])
        XCTAssertEqual(result.map(\.contactName), ["A", "B", "C"])
    }

    func test_chainStops_whenFirstRuleResolves() {
        let chain = SortRuleChain(rules: [UnreadRule(), AlphaRule()])
        // unread 不同 → 第一条已决定顺序,不看第二条
        let result = chain.sort([m("1", name: "Z", unread: 1), m("2", name: "A", unread: 5)])
        XCTAssertEqual(result.map(\.sessionId), ["2", "1"])
    }
}
```

- [ ] **Step 2: 跑测试验证失败**

```bash
xcodebuild test -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:ChatModule-Unit-Tests/SortRuleChainTests 2>&1 | tail -5
```

Expected: `Cannot find 'SortRule' / 'SortRuleChain' in scope`

- [ ] **Step 3: 实现 SortRule + SortRuleChain**

```swift
// Modules/Business/ChatModule/SessionList/Logic/SortRule/SortRule.swift
import Foundation

public protocol SortRule {
    /// .orderedSame 时让出给链表下一个规则
    func compare(_ lhs: SessionCellModel, _ rhs: SessionCellModel) -> ComparisonResult
}

public final class SortRuleChain {
    private let rules: [SortRule]

    public init(rules: [SortRule]) {
        self.rules = rules
    }

    public func sort(_ sessions: [SessionCellModel]) -> [SessionCellModel] {
        sessions.sorted { lhs, rhs in
            for rule in rules {
                switch rule.compare(lhs, rhs) {
                case .orderedAscending:  return true
                case .orderedDescending: return false
                case .orderedSame:       continue
                }
            }
            return false
        }
    }
}
```

- [ ] **Step 4: 跑测试验证通过**

```bash
xcodebuild test -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:ChatModule-Unit-Tests/SortRuleChainTests 2>&1 | tail -5
```

Expected: `Test Suite 'SortRuleChainTests' passed`

- [ ] **Step 5: Commit**

```bash
git add Modules/Business/ChatModule
git commit -m "feat(chat): SortRule protocol + SortRuleChain 链式优先级排序"
```

---

### Task 15: PinnedSortRule + TimestampSortRule

**Files:**
- Create: `Modules/Business/ChatModule/SessionList/Logic/SortRule/PinnedSortRule.swift`
- Create: `Modules/Business/ChatModule/SessionList/Logic/SortRule/TimestampSortRule.swift`

- [ ] **Step 1: PinnedSortRule**

```swift
// Modules/Business/ChatModule/SessionList/Logic/SortRule/PinnedSortRule.swift
import Foundation

public struct PinnedSortRule: SortRule {
    public init() {}

    public func compare(_ lhs: SessionCellModel, _ rhs: SessionCellModel) -> ComparisonResult {
        if lhs.isPinned == rhs.isPinned { return .orderedSame }
        return lhs.isPinned ? .orderedAscending : .orderedDescending
    }
}
```

- [ ] **Step 2: TimestampSortRule (兜底,时间倒序)**

```swift
// Modules/Business/ChatModule/SessionList/Logic/SortRule/TimestampSortRule.swift
import Foundation

public struct TimestampSortRule: SortRule {
    public init() {}

    public func compare(_ lhs: SessionCellModel, _ rhs: SessionCellModel) -> ComparisonResult {
        if lhs.lastTimestamp == rhs.lastTimestamp { return .orderedSame }
        return lhs.lastTimestamp > rhs.lastTimestamp ? .orderedAscending : .orderedDescending
    }
}
```

- [ ] **Step 3: 编译验证 + Commit**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
git add Modules/Business/ChatModule/SessionList/Logic/SortRule/PinnedSortRule.swift Modules/Business/ChatModule/SessionList/Logic/SortRule/TimestampSortRule.swift
git commit -m "feat(chat): PinnedSortRule + TimestampSortRule 基础排序规则"
```

Expected: `BUILD SUCCEEDED`

---

### Task 16: SessionDBHandler — 封装 SessionDB 读取

**Files:**
- Create: `Modules/Business/ChatModule/SessionList/Logic/SessionDBHandler.swift`

- [ ] **Step 1: 实现 SessionDBHandler**

```swift
// Modules/Business/ChatModule/SessionList/Logic/SessionDBHandler.swift
import Foundation
import WCIMSDK

final class SessionDBHandler {
    private let db: SessionDB

    init(db: SessionDB) {
        self.db = db
    }

    func fetchAll() -> [SessionCellModel] {
        db.fetchAll().map(Self.toCellModel)
    }

    func fetch(sessionIds: [String]) -> [SessionCellModel] {
        db.fetch(sessionIds: sessionIds).map(Self.toCellModel)
    }

    // MARK: - 转换

    static func toCellModel(_ m: SessionModel) -> SessionCellModel {
        SessionCellModel(
            sessionId: m.sessionId,
            contactName: m.contactName,
            avatarURL: m.avatarURL,
            lastMsgPreview: m.lastMsgPreview ?? "",
            formattedTime: Self.formatTime(m.lastTimestamp),
            unreadCount: m.unreadCount,
            isPinned: m.isPinned,
            lastTimestamp: m.lastTimestamp
        )
    }

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private static func formatTime(_ ts: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        let cal = Calendar.current
        if cal.isDateInToday(date) { return fmt.string(from: date) }
        if cal.isDateInYesterday(date) { return "昨天" }
        let f = DateFormatter(); f.dateFormat = "M月d日"
        return f.string(from: date)
    }
}
```

- [ ] **Step 2: 编译 + Commit**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
git add Modules/Business/ChatModule/SessionList/Logic/SessionDBHandler.swift
git commit -m "feat(chat): SessionDBHandler 读 SessionDB + 转 CellModel"
```

Expected: `BUILD SUCCEEDED`

---

### Task 17: SessionDBObserver — 订阅 DBChangeStream.sessions

**Files:**
- Create: `Modules/Business/ChatModule/SessionList/Logic/SessionDBObserver.swift`

- [ ] **Step 1: 实现 SessionDBObserver**

```swift
// Modules/Business/ChatModule/SessionList/Logic/SessionDBObserver.swift
import Foundation
import Combine
import WCIMSDK

final class SessionDBObserver {
    /// 输出:有变更时给 Logic,Logic 决定怎么处理
    let changeSubject = PassthroughSubject<SessionChangeEvent, Never>()

    private var cancellable: AnyCancellable?

    func start() {
        cancellable = DBChangeStream.shared.sessionsPublisher
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .sink { [weak self] event in
                self?.changeSubject.send(event)
            }
    }

    func stop() {
        cancellable?.cancel()
        cancellable = nil
    }
}
```

- [ ] **Step 2: 编译 + Commit**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
git add Modules/Business/ChatModule/SessionList/Logic/SessionDBObserver.swift
git commit -m "feat(chat): SessionDBObserver 订阅 DBChangeStream"
```

Expected: `BUILD SUCCEEDED`

---

### Task 18: SessionListLogic — 协调者

**Files:**
- Create: `Modules/Business/ChatModule/SessionList/Logic/SessionListLogic.swift`

- [ ] **Step 1: 实现 SessionListLogic**

```swift
// Modules/Business/ChatModule/SessionList/Logic/SessionListLogic.swift
import Foundation
import Combine
import WCIMSDK

public final class SessionListLogic {

    @Published public private(set) var sessions: [SessionCellModel] = []

    private let handler: SessionDBHandler
    private let observer: SessionDBObserver
    private let sortChain: SortRuleChain
    private var cancellable: AnyCancellable?

    public init(sortChain: SortRuleChain = .default) {
        guard let db = WCIMSDK.sessionDB else {
            fatalError("WCIMSDK.setup must be called before SessionListLogic.init")
        }
        self.handler = SessionDBHandler(db: db)
        self.observer = SessionDBObserver()
        self.sortChain = sortChain
    }

    public func start() {
        // 首次加载全量
        loadAndSort(allFromDB: true)
        // 订阅增量变更
        observer.start()
        cancellable = observer.changeSubject
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .sink { [weak self] event in
                self?.handleChange(event)
            }
    }

    public func stop() {
        cancellable?.cancel()
        observer.stop()
    }

    /// VC viewDidAppear 触发增量同步
    public func triggerRemoteSync() async {
        await WCIMSDK.syncCoordinator?.triggerSync()
    }

    // MARK: - Private

    private func handleChange(_ event: SessionChangeEvent) {
        switch event {
        case .insert, .update:
            loadAndSort(allFromDB: true)  // 简化:全量重读 + 重排
        case .delete(let ids):
            let idSet = Set(ids)
            let filtered = sessions.filter { !idSet.contains($0.sessionId) }
            sessions = filtered  // 删除场景不需要重排
        }
    }

    private func loadAndSort(allFromDB: Bool) {
        let all = handler.fetchAll()
        let sorted = sortChain.sort(all)
        DispatchQueue.main.async { [weak self] in
            self?.sessions = sorted
        }
    }
}

// MARK: - 默认排序链

public extension SortRuleChain {
    static var `default`: SortRuleChain {
        SortRuleChain(rules: [
            PinnedSortRule(),
            TimestampSortRule(),  // 兜底
        ])
    }
}
```

- [ ] **Step 2: 编译 + Commit**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
git add Modules/Business/ChatModule/SessionList/Logic/SessionListLogic.swift
git commit -m "feat(chat): SessionListLogic 协调 DBHandler + DBObserver + SortRuleChain"
```

Expected: `BUILD SUCCEEDED`

---

### Task 19: SessionListCell — Cell 视图

**Files:**
- Create: `Modules/Business/ChatModule/SessionList/View/SessionListCell.swift`

- [ ] **Step 1: 实现 SessionListCell**

```swift
// Modules/Business/ChatModule/SessionList/View/SessionListCell.swift
import UIKit
import SnapKit

public class SessionListCell: UITableViewCell {
    public static let reuseID = "SessionListCell"

    private let avatarView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 6
        v.backgroundColor = UIColor(white: 0.9, alpha: 1)
        v.clipsToBounds = true
        return v
    }()

    private let nameLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 17, weight: .medium)
        l.textColor = UIColor(white: 0.08, alpha: 1)
        return l
    }()

    private let messageLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 14)
        l.textColor = UIColor(white: 0.47, alpha: 1)
        l.lineBreakMode = .byTruncatingTail
        return l
    }()

    private let timeLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 12)
        l.textColor = UIColor(white: 0.67, alpha: 1)
        l.textAlignment = .right
        return l
    }()

    private let badgeLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 11, weight: .semibold)
        l.textColor = .white
        l.backgroundColor = UIColor(red: 1, green: 0.23, blue: 0.19, alpha: 1)
        l.textAlignment = .center
        l.clipsToBounds = true
        l.isHidden = true
        l.layer.cornerRadius = 9
        return l
    }()

    private let pinnedBackground = UIColor(white: 0.96, alpha: 1)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        contentView.backgroundColor = .white
        contentView.addSubview(avatarView)
        contentView.addSubview(nameLabel)
        contentView.addSubview(messageLabel)
        contentView.addSubview(timeLabel)
        contentView.addSubview(badgeLabel)

        avatarView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(14)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(48)
        }
        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(12)
            make.top.equalTo(avatarView)
            make.trailing.lessThanOrEqualTo(timeLabel.snp.leading).offset(-8)
        }
        messageLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.bottom.equalTo(avatarView)
            make.trailing.lessThanOrEqualTo(badgeLabel.snp.leading).offset(-8)
        }
        timeLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-14)
            make.top.equalTo(avatarView)
        }
        badgeLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-14)
            make.bottom.equalTo(avatarView)
            make.height.equalTo(18)
            make.width.greaterThanOrEqualTo(18)
        }
    }

    public func configure(_ m: SessionCellModel) {
        nameLabel.text = m.contactName
        messageLabel.text = m.lastMsgPreview
        timeLabel.text = m.formattedTime
        if m.unreadCount > 0 {
            badgeLabel.isHidden = false
            badgeLabel.text = m.unreadCount > 99 ? "99+" : "\(m.unreadCount)"
        } else {
            badgeLabel.isHidden = true
        }
        contentView.backgroundColor = m.isPinned ? pinnedBackground : .white
    }
}
```

- [ ] **Step 2: 编译 + Commit**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
git add Modules/Business/ChatModule/SessionList/View/SessionListCell.swift
git commit -m "feat(chat): SessionListCell 复用 ChatListCell 视觉,适配 SessionCellModel"
```

Expected: `BUILD SUCCEEDED`

---

### Task 20: SessionListViewController — DiffableDataSource + reconfigureItems

**Files:**
- Create: `Modules/Business/ChatModule/SessionList/VC/SessionListViewController.swift`

- [ ] **Step 1: 实现 SessionListViewController**

```swift
// Modules/Business/ChatModule/SessionList/VC/SessionListViewController.swift
import UIKit
import Combine
import SnapKit
import WeChatUI
import WCIMSDK

public final class SessionListViewController: BaseViewController {

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.delegate = self
        tv.register(SessionListCell.self, forCellReuseIdentifier: SessionListCell.reuseID)
        tv.rowHeight = 78
        tv.separatorStyle = .singleLine
        tv.separatorInset = UIEdgeInsets(top: 0, left: 74, bottom: 0, right: 14)
        tv.separatorColor = UIColor(white: 0.93, alpha: 1)
        tv.backgroundColor = UIColor(white: 0.97, alpha: 1)
        tv.tableFooterView = UIView()
        return tv
    }()

    private enum Section { case main }

    private lazy var dataSource: UITableViewDiffableDataSource<Section, SessionCellModel> = {
        UITableViewDiffableDataSource(tableView: tableView) { tv, indexPath, model in
            let cell = tv.dequeueReusableCell(withIdentifier: SessionListCell.reuseID, for: indexPath) as! SessionListCell
            cell.configure(model)
            return cell
        }
    }()

    private let logic = SessionListLogic()
    private var cancellables = Set<AnyCancellable>()

    public override func viewDidLoad() {
        super.viewDidLoad()
        title = "微信"
        view.backgroundColor = UIColor(white: 0.97, alpha: 1)

        view.addSubview(tableView)
        tableView.snp.makeConstraints { $0.edges.equalToSuperview() }
        _ = dataSource  // 触发懒加载,绑 tableView

        bind()
        logic.start()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task { await logic.triggerRemoteSync() }
    }

    private func bind() {
        logic.$sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.applySnapshot(sessions)
            }
            .store(in: &cancellables)
    }

    private func applySnapshot(_ models: [SessionCellModel]) {
        var snap = NSDiffableDataSourceSnapshot<Section, SessionCellModel>()
        snap.appendSections([.main])
        snap.appendItems(models, toSection: .main)

        // 关键:用 reconfigureItems(iOS 15+)对屏幕上已存在的 cell 走"原地更新"
        // diff 自动算出哪些 item 内容变了,这里把那批 itemIdentifier 标 reconfigure
        let oldSnap = dataSource.snapshot()
        let oldByKey = Dictionary(uniqueKeysWithValues: oldSnap.itemIdentifiers.map { ($0.sessionId, $0) })
        let toReconfigure = models.filter { new in
            if let old = oldByKey[new.sessionId], old != new { return true }
            return false
        }
        if !toReconfigure.isEmpty {
            snap.reconfigureItems(toReconfigure)
        }

        dataSource.apply(snap, animatingDifferences: true)
    }
}

extension SessionListViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // Phase 1:点击只 log,详情页 Phase 2 实现
        if let model = dataSource.itemIdentifier(for: indexPath) {
            print("[SessionList] 点击会话: \(model.sessionId) - \(model.contactName)")
        }
    }
}
```

- [ ] **Step 2: 编译 + Commit**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
git add Modules/Business/ChatModule/SessionList/VC/SessionListViewController.swift
git commit -m "feat(chat): SessionListViewController + DiffableDataSource + reconfigureItems"
```

Expected: `BUILD SUCCEEDED`

---

### Task 21: MainTabBarController 接入 SessionListViewController

**Files:**
- Modify: `WeChatSwift/MainTabBarController.swift`

- [ ] **Step 1: 替换占位为 SessionListViewController**

```swift
// WeChatSwift/MainTabBarController.swift
import UIKit
import ExtensionKit
import ChatModule
import ContactModule
import DiscoverModule
import MeModule

class MainTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupAppearance()
        setupViewControllers()
    }

    private func setupAppearance() {
        tabBar.tintColor = UIColor(hex: "#07C160")
        tabBar.backgroundColor = .white
        tabBar.isTranslucent = false
    }

    private func setupViewControllers() {
        let chat = SessionListViewController()
        chat.tabBarItem = UITabBarItem(
            title: "微信",
            image: UIImage(systemName: "message"),
            selectedImage: UIImage(systemName: "message.fill")
        )

        let contacts = ContactsViewController()
        contacts.tabBarItem = UITabBarItem(
            title: "通讯录",
            image: UIImage(systemName: "person.2"),
            selectedImage: UIImage(systemName: "person.2.fill")
        )

        let discover = DiscoverViewController()
        discover.tabBarItem = UITabBarItem(
            title: "发现",
            image: UIImage(systemName: "safari"),
            selectedImage: UIImage(systemName: "safari.fill")
        )

        let me = MeViewController()
        me.tabBarItem = UITabBarItem(
            title: "我",
            image: UIImage(systemName: "person.crop.circle"),
            selectedImage: UIImage(systemName: "person.crop.circle.fill")
        )

        let wrap: (UIViewController) -> UINavigationController = { rootVC in
            if #available(iOS 26, *), ProcessInfo().operatingSystemVersion.minorVersion < 2 {
                return LayoutForcingNavigationController(rootViewController: rootVC)
            }
            return UINavigationController(rootViewController: rootVC)
        }

        viewControllers = [
            wrap(chat), wrap(contacts), wrap(discover), wrap(me)
        ]
    }
}
```

- [ ] **Step 2: 编译 + 运行 + Commit**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
```

Xcode 里 ⌘R 运行 app,验证:
1. 启动看到 100 个会话(前 3 个置顶背景灰)
2. 控制台 `[Sync] ✅ applied 100 sessions, advanced seqId → 100`
3. 进入 app 1~2 秒后下拉刷新或切到其他 tab 再切回来,console 应有增量同步日志
4. 点击 cell 看到 `[SessionList] 点击会话: ...`

```bash
git add WeChatSwift/MainTabBarController.swift
git commit -m "feat(app): MainTabBarController 接入 SessionListViewController"
```

Expected: `BUILD SUCCEEDED` + 运行 UI 正常

---

### Task 22: Phase 1 集成验证 — 触发增量同步演示动画

**Files:**
- Modify: `Modules/Business/ChatModule/SessionList/VC/SessionListViewController.swift` (临时加调试按钮)

- [ ] **Step 1: 在 SessionListViewController 加一个 navigationBar 右上角按钮触发 sync,验证增量动画**

修改 `viewDidLoad` 末尾:

```swift
navigationItem.rightBarButtonItem = UIBarButtonItem(
    title: "🔄 Sync",
    style: .plain,
    target: self,
    action: #selector(manualSync)
)
```

新增:

```swift
@objc private func manualSync() {
    Task { await logic.triggerRemoteSync() }
}
```

- [ ] **Step 2: 运行手动点 Sync 按钮**

⌘R 运行,顶部点 "🔄 Sync",观察:
- console: `[Sync] ✅ applied 1~3 sessions, advanced seqId → ...`
- 列表里 1~3 个会话变更:时间戳更新 → 排到列表上面 → 有平滑 move 动画(无闪烁、无重建)

- [ ] **Step 3: Commit**

```bash
git add Modules/Business/ChatModule/SessionList/VC/SessionListViewController.swift
git commit -m "feat(chat): SessionListVC 顶部加 Sync 按钮,演示增量动画"
```

---

# Phase 2 · ChatDetail + 发送链路 (~1 周)

---

### Task 23: MessageModel — WCDB TableCodable

**Files:**
- Create: `Modules/Platform/WCIMSDK/Model/MessageModel.swift`

- [ ] **Step 1: 实现 MessageModel**

```swift
// Modules/Platform/WCIMSDK/Model/MessageModel.swift
import Foundation
import WCDBSwift

public enum MessageStatus: Int {
    case sending = 0, sent = 1, failed = 2, received = 3
}

public enum MessageContentType: Int {
    case text = 0
    // image=1, voice=2 ...  Phase 2 仅 text
}

public final class MessageModel: TableCodable, MessageEntityRef {
    public var localMsgId: String = ""
    public var msgId: String?
    public var sessionId: String = ""
    public var seqId: Int64 = 0
    public var senderId: String = ""
    public var contentType: Int = 0
    public var contentJSON: String = ""
    public var timestamp: Int64 = 0
    public var status: Int = 0
    public var traceId: String?

    public init() {}

    public enum CodingKeys: String, CodingTableKey {
        public typealias Root = MessageModel
        case localMsgId, msgId, sessionId, seqId, senderId
        case contentType, contentJSON, timestamp, status, traceId

        public static let objectRelationalMapping = TableBinding(CodingKeys.self) {
            BindColumnConstraint(localMsgId, isPrimary: true)
            BindColumnConstraint(msgId, isUnique: true)
            BindIndex(sessionId, namedWith: "_sessionId")
            BindIndex(seqId, namedWith: "_seqId")
        }
    }
}
```

- [ ] **Step 2: 编译 + Commit**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
git add Modules/Platform/WCIMSDK/Model/MessageModel.swift
git commit -m "feat(wcimsdk): MessageModel TableCodable + 主键唯一约束"
```

Expected: `BUILD SUCCEEDED`

---

### Task 24: MessageDB — 动态建表 + upsert + 分页查询

**Files:**
- Create: `Modules/Platform/WCIMSDK/DB/MessageDB.swift`
- Modify: `Modules/Platform/WCIMSDK/WCIMSDK.swift`

- [ ] **Step 1: 实现 MessageDB**

```swift
// Modules/Platform/WCIMSDK/DB/MessageDB.swift
import Foundation
import WCDBSwift

public final class MessageDB {
    private let db: Database
    private let registry: MessageTableNameRegistry
    private var createdTables: Set<String> = []
    private let lock = NSLock()

    public init(userId: String, registry: MessageTableNameRegistry) {
        let path = DBPaths.messageDBPath(userId: userId)
        self.db = Database(at: path)
        self.registry = registry
    }

    // MARK: - 写

    public func upsert(_ messages: [MessageModel], sessionId: String) throws {
        let table = registry.tableName(for: sessionId)
        try ensureTable(table)
        try db.insertOrReplace(messages, intoTable: table)
    }

    /// 更新单条消息(发送 ACK 回填用)
    public func update(localMsgId: String, sessionId: String, mutate: (MessageModel) -> Void) throws {
        let table = registry.tableName(for: sessionId)
        try ensureTable(table)
        guard let m: MessageModel = try db.getObject(fromTable: table,
            where: MessageModel.Properties.localMsgId == localMsgId) else { return }
        mutate(m)
        try db.insertOrReplace([m], intoTable: table)
    }

    // MARK: - 读

    /// 按 seqId 倒序分页(最新的在前)
    public func fetchPage(sessionId: String, beforeSeqId: Int64? = nil, limit: Int = 20) -> [MessageModel] {
        let table = registry.tableName(for: sessionId)
        try? ensureTable(table)
        do {
            if let before = beforeSeqId {
                return try db.getObjects(
                    fromTable: table,
                    where: MessageModel.Properties.seqId < before,
                    orderBy: [MessageModel.Properties.seqId.asOrder(by: .descending)],
                    limit: limit
                )
            } else {
                return try db.getObjects(
                    fromTable: table,
                    orderBy: [MessageModel.Properties.seqId.asOrder(by: .descending)],
                    limit: limit
                )
            }
        } catch {
            return []
        }
    }

    public func fetch(localMsgIds: [String], sessionId: String) -> [MessageModel] {
        let table = registry.tableName(for: sessionId)
        try? ensureTable(table)
        return (try? db.getObjects(
            fromTable: table,
            where: MessageModel.Properties.localMsgId.in(localMsgIds)
        )) ?? []
    }

    // MARK: - 事务

    public func runTransaction(_ block: () throws -> Void) throws {
        try db.run(transaction: { _ in try block() })
    }

    // MARK: - 私有

    private func ensureTable(_ name: String) throws {
        lock.lock(); defer { lock.unlock() }
        if createdTables.contains(name) { return }
        try db.create(table: name, of: MessageModel.self)
        createdTables.insert(name)
    }
}
```

- [ ] **Step 2: WCIMSDK 初始化 MessageDB**

修改 `WCIMSDK.swift`:

```swift
public enum WCIMSDK {
    public private(set) static var currentUserId: String = ""
    public private(set) static var sessionDB: SessionDB?
    public private(set) static var messageDB: MessageDB?
    public private(set) static var tableRegistry: MessageTableNameRegistry?
    public private(set) static var seqIdManager: SeqIdManager?
    public private(set) static var syncCoordinator: SyncCoordinator?

    public static func setup(userId: String) {
        currentUserId = userId
        let reg = MessageTableNameRegistry()
        let sdb = SessionDB(userId: userId)
        let mdb = MessageDB(userId: userId, registry: reg)
        let seq = SeqIdManager(userId: userId)
        tableRegistry = reg
        sessionDB = sdb
        messageDB = mdb
        seqIdManager = seq
        syncCoordinator = SyncCoordinator(
            service: MockSyncService(),
            sessionDB: sdb,
            messageDB: mdb,
            seqIdManager: seq
        )
    }
}
```

- [ ] **Step 3: SyncCoordinator 支持 messageDB(事务跨两库)**

修改 `SyncCoordinator.init` 签名 + applyBatch:

```swift
public final class SyncCoordinator {
    private let service: SyncServiceProtocol
    private let sessionDB: SessionDB
    private let messageDB: MessageDB
    private let seqIdManager: SeqIdManager
    private let changeStream: DBChangeStream

    public init(service: SyncServiceProtocol, sessionDB: SessionDB,
                messageDB: MessageDB, seqIdManager: SeqIdManager,
                changeStream: DBChangeStream = .shared) {
        self.service = service
        self.sessionDB = sessionDB
        self.messageDB = messageDB
        self.seqIdManager = seqIdManager
        self.changeStream = changeStream
    }

    // triggerSync 不变 ...

    private func applyBatch(_ batch: SyncBatch) throws {
        let messages = (batch.messages as? [MessageModel]) ?? []

        // 按 sessionId 分组
        var sessionGroup: [String: SessionModel] = [:]
        for s in batch.sessions { sessionGroup[s.sessionId] = s }

        var messageGroup: [String: [MessageModel]] = [:]
        for m in messages { messageGroup[m.sessionId, default: []].append(m) }

        let allSessionIds = Array(Set(sessionGroup.keys).union(messageGroup.keys))
        let existing = Set(sessionDB.fetch(sessionIds: allSessionIds).map(\.sessionId))
        let insertedIds = allSessionIds.filter { !existing.contains($0) }
        let updatedIds = allSessionIds.filter { existing.contains($0) }

        try sessionDB.runTransaction {
            try sessionDB.upsert(Array(sessionGroup.values))
            for (sid, msgs) in messageGroup {
                try messageDB.upsert(msgs, sessionId: sid)
            }
        }

        // 事务成功 → 推进 seqId + 广播
        if !insertedIds.isEmpty { changeStream.publish(session: .insert(insertedIds)) }
        if !updatedIds.isEmpty  { changeStream.publish(session: .update(updatedIds)) }
        for (sid, msgs) in messageGroup where !msgs.isEmpty {
            changeStream.publish(message: .insert(sessionId: sid, messages: msgs), sessionId: sid)
        }
    }
}
```

- [ ] **Step 4: 编译 + Commit**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
git add Modules/Platform/WCIMSDK
git commit -m "feat(wcimsdk): MessageDB 动态建表 + 分页查询 + SyncCoordinator 跨库事务"
```

Expected: `BUILD SUCCEEDED`

---

### Task 25: SendQueueManager (TDD)

**Files:**
- Create: `Modules/Platform/WCIMSDK/SendQueueManager.swift`
- Test: `Modules/Platform/WCIMSDK/WCIMSDKTests/SendQueueManagerTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
// Modules/Platform/WCIMSDK/WCIMSDKTests/SendQueueManagerTests.swift
import XCTest
@testable import WCIMSDK

final class SendQueueManagerTests: XCTestCase {
    var mgr: SendQueueManager!

    override func setUp() {
        super.setUp()
        mgr = SendQueueManager()
    }

    func test_sameSession_returnsSameQueue() {
        let a = mgr.queue(for: "s1")
        let b = mgr.queue(for: "s1")
        XCTAssertTrue(a === b)
    }

    func test_differentSessions_returnDifferentQueues() {
        let a = mgr.queue(for: "s1")
        let b = mgr.queue(for: "s2")
        XCTAssertFalse(a === b)
    }

    func test_sameSessionQueue_executesSerially() {
        let q = mgr.queue(for: "s1")
        var order: [Int] = []
        let g = DispatchGroup()
        for i in 1...10 {
            g.enter()
            q.async {
                Thread.sleep(forTimeInterval: 0.005)
                order.append(i)
                g.leave()
            }
        }
        g.wait()
        XCTAssertEqual(order, Array(1...10))
    }
}
```

- [ ] **Step 2: 跑测试验证失败**

```bash
xcodebuild test -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:WCIMSDK-Unit-Tests/SendQueueManagerTests 2>&1 | tail -5
```

Expected: `Cannot find 'SendQueueManager' in scope`

- [ ] **Step 3: 实现**

```swift
// Modules/Platform/WCIMSDK/SendQueueManager.swift
import Foundation

public final class SendQueueManager {
    public static let shared = SendQueueManager()

    private var queues: [String: DispatchQueue] = [:]
    private let lock = NSLock()

    public init() {}

    public func queue(for sessionId: String) -> DispatchQueue {
        lock.lock(); defer { lock.unlock() }
        if let q = queues[sessionId] { return q }
        let q = DispatchQueue(label: "im.send.\(sessionId)")
        queues[sessionId] = q
        return q
    }
}
```

- [ ] **Step 4: 跑测试 + Commit**

```bash
xcodebuild test -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:WCIMSDK-Unit-Tests/SendQueueManagerTests 2>&1 | tail -5
git add Modules/Platform/WCIMSDK
git commit -m "feat(wcimsdk): SendQueueManager 单会话串行 + 跨会话并发"
```

Expected: `passed`

---

### Task 26: PushService — Mock upload + ACK 模拟

**Files:**
- Create: `Modules/Platform/WCIMSDK/Service/PushService.swift`

- [ ] **Step 1: 实现 PushService**

```swift
// Modules/Platform/WCIMSDK/Service/PushService.swift
import Foundation

public struct PushUploadResult {
    public let msgId: String
    public let seqId: Int64
    public let timestamp: Int64
}

public enum PushError: Error {
    case networkFailed
}

public protocol PushServiceProtocol {
    /// 上行一条消息,返回服务端 ACK
    func upload(localMsgId: String, traceId: String,
                sessionId: String, contentJSON: String) async throws -> PushUploadResult
}

public final class MockPushService: PushServiceProtocol {
    public init() {}

    public func upload(localMsgId: String, traceId: String,
                       sessionId: String, contentJSON: String) async throws -> PushUploadResult {
        try await Task.sleep(nanoseconds: 500_000_000)  // 模拟 500ms 网络

        // 10% 失败模拟
        if Int.random(in: 0..<10) == 0 {
            print("[Push] ❌ upload failed (localMsgId=\(localMsgId), trace=\(traceId))")
            throw PushError.networkFailed
        }

        let seq = (WCIMSDK.seqIdManager?.currentSeqId ?? 0) + 1
        let result = PushUploadResult(
            msgId: "srv_" + UUID().uuidString.prefix(12).lowercased(),
            seqId: seq,
            timestamp: Int64(Date().timeIntervalSince1970)
        )
        print("[Push] ✅ ACK localMsgId=\(localMsgId) → msgId=\(result.msgId), seqId=\(result.seqId)")
        return result
    }
}
```

- [ ] **Step 2: WCIMSDK 暴露 PushService**

```swift
// 在 WCIMSDK.swift 增加
public private(set) static var pushService: PushServiceProtocol?

// setup 内追加
pushService = MockPushService()
```

- [ ] **Step 3: 编译 + Commit**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
git add Modules/Platform/WCIMSDK
git commit -m "feat(wcimsdk): MockPushService 模拟 500ms ACK + 10% 失败率"
```

Expected: `BUILD SUCCEEDED`

---

### Task 27: MessageCellModel

**Files:**
- Create: `Modules/Business/ChatModule/ChatDetail/Model/MessageCellModel.swift`

- [ ] **Step 1: 实现**

```swift
// Modules/Business/ChatModule/ChatDetail/Model/MessageCellModel.swift
import Foundation
import WCIMSDK

public struct MessageCellModel: Hashable {
    public let localMsgId: String
    public let msgId: String?
    public let sessionId: String
    public let senderId: String
    public let isFromMe: Bool      // 视觉:我发的右侧绿,对方左侧白
    public let text: String         // text content
    public let timestamp: Int64
    public let status: MessageStatus

    public func hash(into h: inout Hasher) { h.combine(localMsgId) }

    public static func == (l: Self, r: Self) -> Bool {
        l.localMsgId == r.localMsgId
            && l.msgId == r.msgId
            && l.text == r.text
            && l.timestamp == r.timestamp
            && l.status == r.status
    }
}
```

- [ ] **Step 2: 编译 + Commit**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
git add Modules/Business/ChatModule/ChatDetail/Model/MessageCellModel.swift
git commit -m "feat(chat): MessageCellModel Hashable struct"
```

Expected: `BUILD SUCCEEDED`

---

### Task 28: MessageDBHandler — 封装分页查询

**Files:**
- Create: `Modules/Business/ChatModule/ChatDetail/Logic/MessageDBHandler.swift`

- [ ] **Step 1: 实现**

```swift
// Modules/Business/ChatModule/ChatDetail/Logic/MessageDBHandler.swift
import Foundation
import WCIMSDK

final class MessageDBHandler {
    private let db: MessageDB
    private let sessionId: String
    private let myUserId: String

    init(db: MessageDB, sessionId: String, myUserId: String) {
        self.db = db
        self.sessionId = sessionId
        self.myUserId = myUserId
    }

    func fetchPage(beforeSeqId: Int64? = nil, limit: Int = 20) -> [MessageCellModel] {
        db.fetchPage(sessionId: sessionId, beforeSeqId: beforeSeqId, limit: limit)
            .map { toCellModel($0) }
            .reversed()  // VC 显示要时间正序(老在上,新在下)
    }

    func toCellModel(_ m: MessageModel) -> MessageCellModel {
        let payload = (try? JSONDecoder().decode([String: String].self, from: Data(m.contentJSON.utf8))) ?? [:]
        let text = payload["text"] ?? ""
        return MessageCellModel(
            localMsgId: m.localMsgId,
            msgId: m.msgId,
            sessionId: m.sessionId,
            senderId: m.senderId,
            isFromMe: m.senderId == myUserId,
            text: text,
            timestamp: m.timestamp,
            status: MessageStatus(rawValue: m.status) ?? .received
        )
    }
}
```

- [ ] **Step 2: 编译 + Commit**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
git add Modules/Business/ChatModule/ChatDetail/Logic/MessageDBHandler.swift
git commit -m "feat(chat): MessageDBHandler 分页查询 + 转 CellModel"
```

Expected: `BUILD SUCCEEDED`

---

### Task 29: MessageDBObserver

**Files:**
- Create: `Modules/Business/ChatModule/ChatDetail/Logic/MessageDBObserver.swift`

- [ ] **Step 1: 实现**

```swift
// Modules/Business/ChatModule/ChatDetail/Logic/MessageDBObserver.swift
import Foundation
import Combine
import WCIMSDK

final class MessageDBObserver {
    let changeSubject = PassthroughSubject<MessageChangeEvent, Never>()

    private let sessionId: String
    private var cancellable: AnyCancellable?

    init(sessionId: String) {
        self.sessionId = sessionId
    }

    func start() {
        cancellable = DBChangeStream.shared.messagesPublisher(of: sessionId)
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .sink { [weak self] event in
                self?.changeSubject.send(event)
            }
    }

    func stop() {
        cancellable?.cancel()
        cancellable = nil
    }
}
```

- [ ] **Step 2: 编译 + Commit**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
git add Modules/Business/ChatModule/ChatDetail/Logic/MessageDBObserver.swift
git commit -m "feat(chat): MessageDBObserver 按 sessionId 订阅变更"
```

Expected: `BUILD SUCCEEDED`

---

### Task 30: SendMsgHandler — 状态机 + 重试 + 幂等

**Files:**
- Create: `Modules/Business/ChatModule/ChatDetail/Logic/SendMsgHandler.swift`

- [ ] **Step 1: 实现**

```swift
// Modules/Business/ChatModule/ChatDetail/Logic/SendMsgHandler.swift
import Foundation
import WCIMSDK

final class SendMsgHandler {
    private let sessionId: String
    private let myUserId: String
    private let messageDB: MessageDB
    private let sessionDB: SessionDB
    private let pushService: PushServiceProtocol
    private let queue: DispatchQueue

    init(sessionId: String, myUserId: String) {
        self.sessionId = sessionId
        self.myUserId = myUserId
        self.messageDB = WCIMSDK.messageDB!
        self.sessionDB = WCIMSDK.sessionDB!
        self.pushService = WCIMSDK.pushService!
        self.queue = SendQueueManager.shared.queue(for: sessionId)
    }

    /// 入口:发送文本
    func send(text: String) async {
        let localMsgId = UUID().uuidString
        let traceId = UUID().uuidString
        let now = Int64(Date().timeIntervalSince1970)

        // Step 1: 写 DB(status=sending) + Session lastMsg 同步
        let pending = MessageModel()
        pending.localMsgId = localMsgId
        pending.sessionId = sessionId
        pending.senderId = myUserId
        pending.contentType = MessageContentType.text.rawValue
        pending.contentJSON = "{\"text\":\"\(text.replacingOccurrences(of: "\"", with: "\\\""))\"}"
        pending.timestamp = now
        pending.status = MessageStatus.sending.rawValue
        pending.traceId = traceId

        do {
            try messageDB.runTransaction {
                try self.messageDB.upsert([pending], sessionId: self.sessionId)
                // 同步更新 SessionDB 的 lastMsg 字段
                if let s = self.sessionDB.fetch(sessionIds: [self.sessionId]).first {
                    s.lastMsgPreview = text
                    s.lastTimestamp = now
                    try self.sessionDB.upsert([s])
                    DBChangeStream.shared.publish(session: .update([self.sessionId]))
                }
            }
            DBChangeStream.shared.publish(message: .insert(sessionId: sessionId, messages: [pending]), sessionId: sessionId)
        } catch {
            print("[Send] ❌ DB write failed: \(error)")
            return
        }

        // Step 2: 串行排队上行(可能重试)
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            queue.async {
                Task { [weak self] in
                    await self?.uploadWithRetry(localMsgId: localMsgId, traceId: traceId,
                                                contentJSON: pending.contentJSON)
                    cont.resume()
                }
            }
        }
    }

    /// 重发(localMsgId 不变,从 DB 拿原消息再上行)
    func retry(localMsgId: String) async {
        guard let m = messageDB.fetch(localMsgIds: [localMsgId], sessionId: sessionId).first else { return }
        m.status = MessageStatus.sending.rawValue
        let newTraceId = UUID().uuidString
        m.traceId = newTraceId

        do {
            try messageDB.runTransaction {
                try self.messageDB.upsert([m], sessionId: self.sessionId)
            }
            DBChangeStream.shared.publish(message: .update(sessionId: sessionId, messages: [m]), sessionId: sessionId)
        } catch {}

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            queue.async {
                Task { [weak self] in
                    await self?.uploadWithRetry(localMsgId: localMsgId, traceId: newTraceId,
                                                contentJSON: m.contentJSON)
                    cont.resume()
                }
            }
        }
    }

    // MARK: - Private

    private func uploadWithRetry(localMsgId: String, traceId: String, contentJSON: String) async {
        let delays: [UInt64] = [0, 1_000_000_000, 2_000_000_000, 4_000_000_000]  // 立即+1s+2s+4s 共 4 次
        for (i, d) in delays.enumerated() {
            if d > 0 { try? await Task.sleep(nanoseconds: d) }
            do {
                let result = try await pushService.upload(localMsgId: localMsgId,
                                                          traceId: traceId,
                                                          sessionId: sessionId,
                                                          contentJSON: contentJSON)
                applyACK(localMsgId: localMsgId, result: result)
                return
            } catch {
                print("[Send] retry \(i+1)/\(delays.count) failed: \(error)")
            }
        }
        markFailed(localMsgId: localMsgId)
    }

    private func applyACK(localMsgId: String, result: PushUploadResult) {
        do {
            try messageDB.runTransaction {
                try self.messageDB.update(localMsgId: localMsgId, sessionId: self.sessionId) { m in
                    m.msgId = result.msgId
                    m.seqId = result.seqId
                    m.status = MessageStatus.sent.rawValue
                    m.timestamp = result.timestamp
                }
            }
            if let m = messageDB.fetch(localMsgIds: [localMsgId], sessionId: sessionId).first {
                DBChangeStream.shared.publish(message: .update(sessionId: sessionId, messages: [m]), sessionId: sessionId)
            }
        } catch {}
    }

    private func markFailed(localMsgId: String) {
        do {
            try messageDB.runTransaction {
                try self.messageDB.update(localMsgId: localMsgId, sessionId: self.sessionId) { m in
                    m.status = MessageStatus.failed.rawValue
                }
            }
            if let m = messageDB.fetch(localMsgIds: [localMsgId], sessionId: sessionId).first {
                DBChangeStream.shared.publish(message: .update(sessionId: sessionId, messages: [m]), sessionId: sessionId)
            }
        } catch {}
    }
}
```

- [ ] **Step 2: 编译 + Commit**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
git add Modules/Business/ChatModule/ChatDetail/Logic/SendMsgHandler.swift
git commit -m "feat(chat): SendMsgHandler 状态机 + 串行排队 + 4 次重试 + ACK 回填"
```

Expected: `BUILD SUCCEEDED`

---

### Task 31: ChatDetailLogic — 协调者

**Files:**
- Create: `Modules/Business/ChatModule/ChatDetail/Logic/ChatDetailLogic.swift`

- [ ] **Step 1: 实现**

```swift
// Modules/Business/ChatModule/ChatDetail/Logic/ChatDetailLogic.swift
import Foundation
import Combine
import WCIMSDK

public final class ChatDetailLogic {
    @Published public private(set) var messages: [MessageCellModel] = []

    public let sessionId: String
    public let contactName: String
    private let handler: MessageDBHandler
    private let observer: MessageDBObserver
    private let sender: SendMsgHandler
    private var cancellable: AnyCancellable?

    public init(sessionId: String, contactName: String) {
        guard let db = WCIMSDK.messageDB else {
            fatalError("WCIMSDK.setup must be called first")
        }
        self.sessionId = sessionId
        self.contactName = contactName
        self.handler = MessageDBHandler(db: db, sessionId: sessionId, myUserId: WCIMSDK.currentUserId)
        self.observer = MessageDBObserver(sessionId: sessionId)
        self.sender = SendMsgHandler(sessionId: sessionId, myUserId: WCIMSDK.currentUserId)
    }

    public func start() {
        loadFirstPage()
        observer.start()
        cancellable = observer.changeSubject
            .receive(on: DispatchQueue.global(qos: .userInitiated))
            .sink { [weak self] _ in self?.reload() }
    }

    public func stop() {
        cancellable?.cancel()
        observer.stop()
    }

    // MARK: - 命令

    public func send(_ text: String) async {
        await sender.send(text: text)
    }

    public func retry(_ localMsgId: String) async {
        await sender.retry(localMsgId: localMsgId)
    }

    // MARK: - 私有

    private func loadFirstPage() {
        let page = handler.fetchPage(beforeSeqId: nil, limit: 50)
        DispatchQueue.main.async { [weak self] in self?.messages = page }
    }

    private func reload() {
        let page = handler.fetchPage(beforeSeqId: nil, limit: 50)
        DispatchQueue.main.async { [weak self] in self?.messages = page }
    }
}
```

- [ ] **Step 2: 编译 + Commit**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
git add Modules/Business/ChatModule/ChatDetail/Logic/ChatDetailLogic.swift
git commit -m "feat(chat): ChatDetailLogic 协调 DBObserver + Handler + Sender"
```

Expected: `BUILD SUCCEEDED`

---

### Task 32: ChatInputBar — 底部输入栏

**Files:**
- Create: `Modules/Business/ChatModule/ChatDetail/View/ChatInputBar.swift`

- [ ] **Step 1: 实现**

```swift
// Modules/Business/ChatModule/ChatDetail/View/ChatInputBar.swift
import UIKit
import SnapKit

public protocol ChatInputBarDelegate: AnyObject {
    func inputBarDidSend(_ text: String)
}

public final class ChatInputBar: UIView {
    public weak var delegate: ChatInputBarDelegate?

    private let textField: UITextField = {
        let tf = UITextField()
        tf.borderStyle = .roundedRect
        tf.font = .systemFont(ofSize: 16)
        tf.placeholder = "输入消息..."
        return tf
    }()

    private let sendButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("发送", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        b.backgroundColor = UIColor(red: 0.027, green: 0.756, blue: 0.376, alpha: 1)
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 6
        return b
    }()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0.97, alpha: 1)
        addSubview(textField)
        addSubview(sendButton)

        textField.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.top.equalToSuperview().offset(8)
            make.bottom.equalToSuperview().offset(-8)
            make.height.equalTo(36)
        }
        sendButton.snp.makeConstraints { make in
            make.leading.equalTo(textField.snp.trailing).offset(10)
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalTo(textField)
            make.width.equalTo(56)
            make.height.equalTo(36)
        }

        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func sendTapped() {
        guard let text = textField.text, !text.isEmpty else { return }
        delegate?.inputBarDidSend(text)
        textField.text = ""
    }
}
```

- [ ] **Step 2: 编译 + Commit**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
git add Modules/Business/ChatModule/ChatDetail/View/ChatInputBar.swift
git commit -m "feat(chat): ChatInputBar 文本输入栏 + 发送按钮"
```

Expected: `BUILD SUCCEEDED`

---

### Task 33: BaseMessageCell + TextMessageCell

**Files:**
- Create: `Modules/Business/ChatModule/ChatDetail/View/Cells/BaseMessageCell.swift`
- Create: `Modules/Business/ChatModule/ChatDetail/View/Cells/TextMessageCell.swift`

- [ ] **Step 1: BaseMessageCell**

```swift
// Modules/Business/ChatModule/ChatDetail/View/Cells/BaseMessageCell.swift
import UIKit
import SnapKit
import WCIMSDK

public class BaseMessageCell: UITableViewCell {

    let bubbleView: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 8
        return v
    }()

    let statusIndicator: UIActivityIndicatorView = {
        let s = UIActivityIndicatorView(style: .medium)
        s.hidesWhenStopped = true
        return s
    }()

    let failedIcon: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "exclamationmark.circle.fill"))
        iv.tintColor = .systemRed
        iv.isHidden = true
        return iv
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.backgroundColor = .white
        contentView.addSubview(bubbleView)
        contentView.addSubview(statusIndicator)
        contentView.addSubview(failedIcon)
        selectionStyle = .none
    }
    required init?(coder: NSCoder) { fatalError() }

    func applyStatus(_ status: MessageStatus, isFromMe: Bool) {
        switch status {
        case .sending:
            statusIndicator.startAnimating()
            failedIcon.isHidden = true
        case .sent, .received:
            statusIndicator.stopAnimating()
            failedIcon.isHidden = true
        case .failed:
            statusIndicator.stopAnimating()
            failedIcon.isHidden = false
        }
    }
}
```

- [ ] **Step 2: TextMessageCell**

```swift
// Modules/Business/ChatModule/ChatDetail/View/Cells/TextMessageCell.swift
import UIKit
import SnapKit
import WCIMSDK

public final class TextMessageCell: BaseMessageCell {
    public static let reuseID = "TextMessageCell"

    private let textLabel_: UILabel = {
        let l = UILabel()
        l.numberOfLines = 0
        l.font = .systemFont(ofSize: 16)
        l.textColor = UIColor(white: 0.1, alpha: 1)
        return l
    }()

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        bubbleView.addSubview(textLabel_)
        textLabel_.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12))
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    public func configure(_ m: MessageCellModel) {
        textLabel_.text = m.text
        bubbleView.backgroundColor = m.isFromMe
            ? UIColor(red: 0.58, green: 0.93, blue: 0.45, alpha: 1)
            : UIColor(white: 0.95, alpha: 1)

        bubbleView.snp.remakeConstraints { make in
            make.top.bottom.equalToSuperview().inset(6)
            make.width.lessThanOrEqualTo(260)
            if m.isFromMe {
                make.trailing.equalToSuperview().offset(-14)
            } else {
                make.leading.equalToSuperview().offset(14)
            }
        }

        statusIndicator.snp.remakeConstraints { make in
            make.centerY.equalTo(bubbleView)
            if m.isFromMe {
                make.trailing.equalTo(bubbleView.snp.leading).offset(-6)
            } else {
                make.leading.equalTo(bubbleView.snp.trailing).offset(6)
            }
            make.width.height.equalTo(20)
        }

        failedIcon.snp.remakeConstraints { make in
            make.center.equalTo(statusIndicator)
            make.width.height.equalTo(22)
        }

        applyStatus(m.status, isFromMe: m.isFromMe)
    }
}
```

- [ ] **Step 3: 编译 + Commit**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
git add Modules/Business/ChatModule/ChatDetail/View/Cells/
git commit -m "feat(chat): BaseMessageCell + TextMessageCell 气泡 + 状态指示"
```

Expected: `BUILD SUCCEEDED`

---

### Task 34: ChatDetailViewController

**Files:**
- Create: `Modules/Business/ChatModule/ChatDetail/VC/ChatDetailViewController.swift`

- [ ] **Step 1: 实现**

```swift
// Modules/Business/ChatModule/ChatDetail/VC/ChatDetailViewController.swift
import UIKit
import Combine
import SnapKit
import WCIMSDK
import WeChatUI
import WeChatRouter
import NavigateKit

public final class ChatDetailViewController: BaseViewController, PageRoutable {

    public static var routePattern: String { "chat/detail" }
    public static func createPage(with params: [String : String]) -> UIViewController? {
        guard let sessionId = params["sessionId"] else { return nil }
        let name = params["contactName"] ?? "聊天"
        return ChatDetailViewController(sessionId: sessionId, contactName: name)
    }

    private enum Section { case main }
    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .plain)
        tv.delegate = self
        tv.register(TextMessageCell.self, forCellReuseIdentifier: TextMessageCell.reuseID)
        tv.separatorStyle = .none
        tv.backgroundColor = .white
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 60
        return tv
    }()

    private lazy var dataSource: UITableViewDiffableDataSource<Section, MessageCellModel> = {
        UITableViewDiffableDataSource(tableView: tableView) { tv, ip, m in
            let cell = tv.dequeueReusableCell(withIdentifier: TextMessageCell.reuseID, for: ip) as! TextMessageCell
            cell.configure(m)
            return cell
        }
    }()

    private let inputBar = ChatInputBar()
    private let logic: ChatDetailLogic
    private var cancellables = Set<AnyCancellable>()

    public init(sessionId: String, contactName: String) {
        self.logic = ChatDetailLogic(sessionId: sessionId, contactName: contactName)
        super.init(nibName: nil, bundle: nil)
        title = contactName
    }
    required init?(coder: NSCoder) { fatalError() }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        view.addSubview(tableView)
        view.addSubview(inputBar)
        inputBar.delegate = self

        tableView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(inputBar.snp.top)
        }
        inputBar.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(52)
        }

        _ = dataSource
        bind()
        logic.start()
    }

    private func bind() {
        logic.$messages
            .receive(on: DispatchQueue.main)
            .sink { [weak self] messages in
                self?.apply(messages)
            }
            .store(in: &cancellables)
    }

    private func apply(_ models: [MessageCellModel]) {
        var snap = NSDiffableDataSourceSnapshot<Section, MessageCellModel>()
        snap.appendSections([.main])
        snap.appendItems(models, toSection: .main)

        let old = dataSource.snapshot()
        let oldByKey = Dictionary(uniqueKeysWithValues: old.itemIdentifiers.map { ($0.localMsgId, $0) })
        let toReconfigure = models.filter { new in
            if let oldM = oldByKey[new.localMsgId], oldM != new { return true }
            return false
        }
        if !toReconfigure.isEmpty {
            snap.reconfigureItems(toReconfigure)
        }

        dataSource.apply(snap, animatingDifferences: true) { [weak self] in
            self?.scrollToBottomIfNeeded(count: models.count)
        }
    }

    private func scrollToBottomIfNeeded(count: Int) {
        guard count > 0 else { return }
        let ip = IndexPath(row: count - 1, section: 0)
        tableView.scrollToRow(at: ip, at: .bottom, animated: true)
    }
}

extension ChatDetailViewController: ChatInputBarDelegate {
    public func inputBarDidSend(_ text: String) {
        Task { await logic.send(text) }
    }
}

extension ChatDetailViewController: UITableViewDelegate {
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let model = dataSource.itemIdentifier(for: indexPath) else { return }
        if model.status == .failed {
            Task { await logic.retry(model.localMsgId) }
        }
    }
}
```

- [ ] **Step 2: 编译 + Commit**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
git add Modules/Business/ChatModule/ChatDetail/VC/ChatDetailViewController.swift
git commit -m "feat(chat): ChatDetailViewController 原生实现 + 路由 + 失败点击重发"
```

Expected: `BUILD SUCCEEDED`

---

### Task 35: 路由 + ChatModule.registerRoutes + SessionListVC 跳转

**Files:**
- Modify: `Modules/WeChatKit/WeChatRouter/Routes.swift`
- Modify: `Modules/Business/ChatModule/ChatModule.swift`
- Modify: `Modules/Business/ChatModule/SessionList/VC/SessionListViewController.swift`

- [ ] **Step 1: Routes.chatDetail 改原生 URL**

修改 `Modules/WeChatKit/WeChatRouter/Routes.swift`:

```swift
public static let chatDetail = "wechat://chat/detail"
```

- [ ] **Step 2: ChatModule.registerRoutes 注册原生**

```swift
// Modules/Business/ChatModule/ChatModule.swift
import UIKit
import WeChatRouter

extension ChatModule: ModuleRoutable {
    public static func registerRoutes() {
        ChatDetailViewController.registerPageRoute()
    }
}

public class ChatModule {
    public static let shared = ChatModule()
    private init() {}
}
```

- [ ] **Step 3: AppDelegate 调 ChatModule.registerRoutes()**

在 AppDelegate 的 `application(_:didFinishLaunchingWithOptions:)` 里(LaunchScheduler.start() 之后,observeFirstFrame 之前)追加:

```swift
ChatModule.registerRoutes()
```

注:`import ChatModule` 需要加。

- [ ] **Step 4: SessionListViewController 点击跳转改原生路由**

修改 `tableView(_:didSelectRowAt:)`:

```swift
public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)
    if let model = dataSource.itemIdentifier(for: indexPath) {
        let encodedName = model.contactName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let url = "\(Routes.chatDetail)?sessionId=\(model.sessionId)&contactName=\(encodedName)"
        Router.shared.push(url)
    }
}
```

需要 `import WeChatRouter`。

- [ ] **Step 5: 编译 + 运行验证**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
```

⌘R 运行,点击会话 → 进入 ChatDetailViewController,发消息验证:
1. 消息立刻出现(sending 状态,转圈)
2. 500ms 后变成 sent 状态(转圈消失)
3. 偶尔 10% 失败时显示红色 ⚠️,点击重发

- [ ] **Step 6: Commit**

```bash
git add Modules/WeChatKit/WeChatRouter/Routes.swift Modules/Business/ChatModule/ChatModule.swift Modules/Business/ChatModule/SessionList/VC/SessionListViewController.swift WeChatSwift/AppDelegate.swift
git commit -m "feat(chat): chatDetail 路由改原生 + SessionListVC 跳转打通"
```

---

# Phase 3 · 横切补强 (~3-5 天)

---

### Task 36: MessageRenderCache — 高度 + 富文本缓存 (TDD)

**Files:**
- Create: `Modules/Business/ChatModule/ChatDetail/Logic/MessageRenderCache.swift`
- Test: `Modules/Business/ChatModule/ChatModuleTests/MessageRenderCacheTests.swift`

- [ ] **Step 1: 写失败测试**

```swift
// Modules/Business/ChatModule/ChatModuleTests/MessageRenderCacheTests.swift
import XCTest
@testable import ChatModule

final class MessageRenderCacheTests: XCTestCase {
    var cache: MessageRenderCache!

    override func setUp() {
        super.setUp()
        cache = MessageRenderCache()
    }

    func test_emptyCache_returnsNil() {
        XCTAssertNil(cache.height(for: "k1"))
        XCTAssertNil(cache.attributedText(for: "k1"))
    }

    func test_storeAndRetrieve_height() {
        cache.cache(height: 42, attributedText: nil, for: "k1")
        XCTAssertEqual(cache.height(for: "k1"), 42)
    }

    func test_storeAndRetrieve_attributedText() {
        let attr = NSAttributedString(string: "hello")
        cache.cache(height: 30, attributedText: attr, for: "k1")
        XCTAssertEqual(cache.attributedText(for: "k1"), attr)
    }

    func test_invalidate_removesEntry() {
        cache.cache(height: 42, attributedText: nil, for: "k1")
        cache.invalidate(["k1"])
        XCTAssertNil(cache.height(for: "k1"))
    }
}
```

- [ ] **Step 2: 跑测试验证失败**

```bash
xcodebuild test -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:ChatModule-Unit-Tests/MessageRenderCacheTests 2>&1 | tail -5
```

Expected: `Cannot find 'MessageRenderCache' in scope`

- [ ] **Step 3: 实现**

```swift
// Modules/Business/ChatModule/ChatDetail/Logic/MessageRenderCache.swift
import UIKit

public final class MessageRenderCache {
    private struct Entry {
        let height: CGFloat
        let attributedText: NSAttributedString?
    }
    private var storage: [String: Entry] = [:]
    private let lock = NSLock()

    public init() {}

    public func height(for key: String) -> CGFloat? {
        lock.lock(); defer { lock.unlock() }
        return storage[key]?.height
    }

    public func attributedText(for key: String) -> NSAttributedString? {
        lock.lock(); defer { lock.unlock() }
        return storage[key]?.attributedText
    }

    public func cache(height: CGFloat, attributedText: NSAttributedString?, for key: String) {
        lock.lock(); defer { lock.unlock() }
        storage[key] = Entry(height: height, attributedText: attributedText)
    }

    public func invalidate(_ keys: [String]) {
        lock.lock(); defer { lock.unlock() }
        for k in keys { storage.removeValue(forKey: k) }
    }
}
```

- [ ] **Step 4: 跑测试 + Commit**

```bash
xcodebuild test -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:ChatModule-Unit-Tests/MessageRenderCacheTests 2>&1 | tail -5
git add Modules/Business/ChatModule
git commit -m "feat(chat): MessageRenderCache 高度 + 富文本缓存,线程安全"
```

Expected: `passed`

---

### Task 37: MessageDBHandler 集成 MessageRenderCache 预计算

**Files:**
- Modify: `Modules/Business/ChatModule/ChatDetail/Logic/MessageDBHandler.swift`

- [ ] **Step 1: 注入 RenderCache,fetchPage 后台预算高度**

修改 `MessageDBHandler.swift`:

```swift
final class MessageDBHandler {
    private let db: MessageDB
    private let sessionId: String
    private let myUserId: String
    private let renderCache: MessageRenderCache

    init(db: MessageDB, sessionId: String, myUserId: String,
         renderCache: MessageRenderCache = .init()) {
        self.db = db
        self.sessionId = sessionId
        self.myUserId = myUserId
        self.renderCache = renderCache
    }

    func fetchPage(beforeSeqId: Int64? = nil, limit: Int = 20) -> [MessageCellModel] {
        let raw = db.fetchPage(sessionId: sessionId, beforeSeqId: beforeSeqId, limit: limit)
        let models = raw.map { toCellModel($0) }.reversed()
        // 后台批量预算高度
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.precalculate(models: Array(models))
        }
        return Array(models)
    }

    // 预算 height: 简单实现 = label boundingRect(width=260)
    private func precalculate(models: [MessageCellModel]) {
        let maxWidth: CGFloat = 260
        let font = UIFont.systemFont(ofSize: 16)
        for m in models {
            guard renderCache.height(for: m.localMsgId) == nil else { continue }
            let rect = (m.text as NSString).boundingRect(
                with: CGSize(width: maxWidth - 24, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil
            )
            renderCache.cache(height: ceil(rect.height) + 32, attributedText: nil, for: m.localMsgId)
        }
    }

    // toCellModel 不变 ...
}
```

注:`renderCache` 可以从外部传入,ChatDetailLogic 持有,跨 fetchPage 调用复用。

- [ ] **Step 2: ChatDetailLogic 持有 renderCache 并暴露给 VC**

修改 `ChatDetailLogic`:

```swift
public final class ChatDetailLogic {
    public let renderCache = MessageRenderCache()
    // ...
    public init(sessionId: String, contactName: String) {
        // ...
        self.handler = MessageDBHandler(db: db, sessionId: sessionId, myUserId: WCIMSDK.currentUserId, renderCache: renderCache)
        // ...
    }
}
```

- [ ] **Step 3: VC 用 renderCache 拿高度(可选,这里 estimatedRowHeight 已能凑合)**

如果想让滚动绝对零计算,VC 实现 `tableView(_:heightForRowAt:)`:

```swift
public func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    guard let model = dataSource.itemIdentifier(for: indexPath) else { return UITableView.automaticDimension }
    return logic.renderCache.height(for: model.localMsgId) ?? UITableView.automaticDimension
}
```

- [ ] **Step 4: 编译 + Commit**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
git add Modules/Business/ChatModule
git commit -m "feat(chat): MessageDBHandler 接入 RenderCache 后台预算 + VC heightForRow O(1)"
```

Expected: `BUILD SUCCEEDED`

---

### Task 38: DraftSortRule

**Files:**
- Create: `Modules/Business/ChatModule/SessionList/Logic/SortRule/DraftSortRule.swift`

- [ ] **Step 1: SessionCellModel 加 draft 字段**

修改 `SessionCellModel.swift`,加 `public let draft: String?` 字段,并补 hash/== / init。同步在 `SessionDBHandler.toCellModel` 中传入 `m.draft`。

```swift
public struct SessionCellModel: Hashable {
    // ... 已有字段
    public let draft: String?

    public init(sessionId: String, contactName: String, avatarURL: String?,
                lastMsgPreview: String, formattedTime: String,
                unreadCount: Int, isPinned: Bool, lastTimestamp: Int64,
                draft: String? = nil) {
        // ... 已有
        self.draft = draft
    }

    public static func == (l: Self, r: Self) -> Bool {
        // ... 已有比较
        && l.draft == r.draft
    }
}
```

- [ ] **Step 2: DraftSortRule**

```swift
// Modules/Business/ChatModule/SessionList/Logic/SortRule/DraftSortRule.swift
import Foundation

public struct DraftSortRule: SortRule {
    public init() {}

    public func compare(_ lhs: SessionCellModel, _ rhs: SessionCellModel) -> ComparisonResult {
        let lHas = !(lhs.draft?.isEmpty ?? true)
        let rHas = !(rhs.draft?.isEmpty ?? true)
        if lHas == rHas { return .orderedSame }
        return lHas ? .orderedAscending : .orderedDescending
    }
}
```

- [ ] **Step 3: 加进默认链**

修改 `SortRuleChain.default`:

```swift
public extension SortRuleChain {
    static var `default`: SortRuleChain {
        SortRuleChain(rules: [
            PinnedSortRule(),
            DraftSortRule(),
            TimestampSortRule(),
        ])
    }
}
```

- [ ] **Step 4: 编译 + Commit**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
git add Modules/Business/ChatModule
git commit -m "feat(chat): DraftSortRule + SessionCellModel.draft 字段"
```

Expected: `BUILD SUCCEEDED`

---

### Task 39: UnreadFirstSortRule

**Files:**
- Create: `Modules/Business/ChatModule/SessionList/Logic/SortRule/UnreadFirstSortRule.swift`

- [ ] **Step 1: 实现 + 编译 + Commit**

```swift
// Modules/Business/ChatModule/SessionList/Logic/SortRule/UnreadFirstSortRule.swift
import Foundation

public struct UnreadFirstSortRule: SortRule {
    public init() {}

    public func compare(_ lhs: SessionCellModel, _ rhs: SessionCellModel) -> ComparisonResult {
        let lUnread = lhs.unreadCount > 0
        let rUnread = rhs.unreadCount > 0
        if lUnread == rUnread { return .orderedSame }
        return lUnread ? .orderedAscending : .orderedDescending
    }
}
```

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
git add Modules/Business/ChatModule/SessionList/Logic/SortRule/UnreadFirstSortRule.swift
git commit -m "feat(chat): UnreadFirstSortRule 可选未读优先排序"
```

Expected: `BUILD SUCCEEDED`

---

### Task 40: 触发源完善 — 前后台 + 网络恢复 + 定时兜底

**Files:**
- Modify: `Modules/Platform/WCIMSDK/Service/SyncService.swift` (加 SyncTriggers)
- Modify: `Modules/Platform/WCIMSDK/WCIMSDK.swift`

- [ ] **Step 1: 实现 SyncTriggers**

在 `SyncService.swift` 文件末尾追加:

```swift
import UIKit
import Network

public final class SyncTriggers {
    private let coordinator: SyncCoordinator
    private var pathMonitor: NWPathMonitor?
    private var pollTimer: Timer?

    public init(coordinator: SyncCoordinator) {
        self.coordinator = coordinator
    }

    public func start() {
        // 前台
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleForeground),
            name: UIApplication.didBecomeActiveNotification, object: nil
        )
        // 网络恢复
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            if path.status == .satisfied {
                Task { await self?.coordinator.triggerSync() }
            }
        }
        monitor.start(queue: DispatchQueue(label: "im.sync.netpath"))
        pathMonitor = monitor
        // 定时兜底
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.pollTimer = Timer.scheduledTimer(withTimeInterval: 90, repeats: true) { [weak self] _ in
                Task { await self?.coordinator.triggerSync() }
            }
        }
    }

    @objc private func handleForeground() {
        Task { await coordinator.triggerSync() }
    }
}
```

- [ ] **Step 2: WCIMSDK setup 时启动**

修改 `WCIMSDK.swift`,在 `syncCoordinator` 初始化后加:

```swift
public private(set) static var syncTriggers: SyncTriggers?

// setup 内
let triggers = SyncTriggers(coordinator: syncCoordinator!)
triggers.start()
syncTriggers = triggers
```

- [ ] **Step 3: 编译 + 验证**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
```

运行后切到后台再回前台,console 应有新的 `[Sync] ✅ applied ...` 日志。

- [ ] **Step 4: Commit**

```bash
git add Modules/Platform/WCIMSDK
git commit -m "feat(wcimsdk): SyncTriggers 前后台 + 网络恢复 + 90s 定时兜底"
```

---

### Task 41: traceId 日志闭环 (DEBUG)

**Files:**
- Modify: `Modules/Business/ChatModule/ChatDetail/Logic/SendMsgHandler.swift`

- [ ] **Step 1: 在关键节点打 traceId 日志**

在 SendMsgHandler 各关键函数里补充打印:

```swift
// send 入口
print("[Trace][\(traceId)] write DB sending localMsgId=\(localMsgId)")

// uploadWithRetry 每次循环开头
print("[Trace][\(traceId)] upload attempt \(i+1) localMsgId=\(localMsgId)")

// applyACK
print("[Trace][\(traceId)] ACK localMsgId=\(localMsgId) → msgId=\(result.msgId) seqId=\(result.seqId)")

// markFailed
print("[Trace][\(traceId)] FAILED localMsgId=\(localMsgId) after all retries")
```

- [ ] **Step 2: 编译 + 运行验证**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -3
```

⌘R 发消息,观察 console 中 traceId 串起完整链路:`write DB` → `upload attempt` → `ACK` / `FAILED`。

- [ ] **Step 3: Commit**

```bash
git add Modules/Business/ChatModule/ChatDetail/Logic/SendMsgHandler.swift
git commit -m "feat(chat): traceId 日志闭环 — DB 写入 → 上行 → ACK"
```

---

### Task 42: 仓库根 README + 架构图

**Files:**
- Modify: `README.md` (项目根)

- [ ] **Step 1: 写 IM 2.0 章节进 README**

在 `README.md` 顶部加一段:

```markdown
## IM 2.0 重构骨架 (2026-05)

WeChatSwift 中聊天模块已按 IM 2.0 架构重构,演示了"分层 + Sync 主线 + 可插拔排序 + 详情页基础收发"完整链路。

### 设计文档与计划

- 设计:`docs/superpowers/specs/2026-05-30-im2-refactor-design.md`
- 实施:`docs/superpowers/plans/2026-05-30-im2-refactor.md`

### 模块结构

- `Modules/Platform/WCIMSDK` —— IM 通用基础设施(Service / DB / 变更广播)
- `Modules/Business/ChatModule` —— UI(MVVM 分层 SessionList / ChatDetail)

### 演示路径

1. 启动 app → 进入"微信"tab
2. 看到 100 个 mock 会话(前 3 个置顶)
3. 顶部 🔄 Sync 按钮:手动触发增量同步,观察列表增量动画
4. 点击会话进入详情 → 发文本消息:sending → sent / failed 状态翻转
5. console 看 [Sync] / [Push] / [Trace] 日志,完整观察 Sync 主线 + 收发链路

### B 档未来演进(spec 第十二节)

- 真 WebSocket + 弱网重连
- YYAsyncLayer 异步绘制气泡
- 大图缩略图 + 滚动降级
- 跨会话全局搜索
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: README 加入 IM 2.0 重构骨架章节"
```

---

### Task 43: Phase 3 最终验证 + Demo 录制

**Files:** (无新文件)

- [ ] **Step 1: 完整跑一遍 demo**

⌘R 运行 app,按 README 演示路径走一遍:
1. 启动 → 看到 100 会话(前 3 灰底置顶)
2. console 有 `[Sync] ✅ applied 100 sessions`
3. 点 🔄 Sync → 列表平滑增量动画
4. 切到其他 tab 再回来 → 触发增量(因为 viewDidAppear)
5. 切到后台再回前台 → 触发增量(SyncTriggers)
6. 等 90s → 定时兜底触发
7. 点会话进详情 → 发 3 条消息
8. 部分自动 ACK 成 sent
9. 偶尔 failed → 点击红色 ⚠️ 重发,console 显示 traceId 新生成
10. console 完整 [Trace][xxx-...] write/upload/ACK 链路日志

- [ ] **Step 2: 录屏 + 截图保存到 docs**

录一段 30s 的演示视频(或截 4-5 张关键截图)放到 `docs/superpowers/demos/im2-demo.mp4` (或 .png)。

```bash
mkdir -p docs/superpowers/demos
# 手动放录屏文件到 docs/superpowers/demos/
git add docs/superpowers/demos/
git commit -m "docs(im2): 添加 IM 2.0 骨架 demo 演示"
```

- [ ] **Step 3: 跑所有单元测试确保绿**

```bash
xcodebuild test -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'platform=iOS Simulator,name=iPhone 15' 2>&1 | tail -20
```

Expected: `** TEST SUCCEEDED **` —— `MessageTableNameRegistryTests` / `SeqIdManagerTests` / `SendQueueManagerTests` / `SessionCellModelTests` / `SortRuleChainTests` / `MessageRenderCacheTests` 全 passed。

- [ ] **Step 4: Final commit (如果有 demo 文件外的杂项)**

```bash
git status
# 如有未提交杂项:
git add -A
git commit -m "chore: Phase 3 收尾 — 测试全绿 + demo 入库"
```

---

## 完成

**总任务数:** 43 个
**预估总工时:** 约 3 周(P1 1 周 + P2 1 周 + P3 3~5 天)

按上面顺序逐 Task 执行,每 Task 完成后 commit,保持仓库始终绿。
