# IM 2.0 重构设计文档

**日期**：2026-05-30
**范围**：A 档骨架级 —— 分层 + Sync 主线 + 会话列表可插拔排序 + 详情页基础收发
**目标**：在简历投递窗口期内 ship 一份"可演示、可讲述"的 IM 2.0 重构骨架

---

## 一、背景与目标

### 现状

`Modules/Business/ChatModule` 目前只有一个静态 mock 列表 `ChatViewController`，详情页是 RN 写的（`wechat://rn?page=chat`），缺乏分层、缺乏数据流、缺乏可演示链路。

### 目标

把简历里"主导商家端 IM 2.0 架构重构 —— 将页面接口驱动升级为基于 Sync 的消息主线，统一消息落库、会话更新与 UI 刷新链路"这段经历的核心架构以骨架形式落地到 WeChatSwift，达到：

1. **分层清晰**：UI / Logic / DB / Service 单向数据流
2. **链路可演示**：从 MockSync → DB 事务 → DBChangeStream → UI 增量刷新跑得通
3. **关键专项有抓手**：可插拔排序（SortRuleChain）、DiffableDataSource + reconfigureItems、单会话串行发送队列、localMsgId/msgId 幂等、MessageRenderCache
4. **B 档专项明确边界**：未做的部分（真 WebSocket、YYAsyncLayer、滚动降级）作为"未来演进"在 spec 中显式列出，面试时讲清楚"骨架/线上"两层叙事

### 非目标

- 真 WebSocket 长连接 / 真弱网测试 / 真断线重连
- 复杂消息类型（图片 / 语音 / 视频）—— A 档只做文本
- YYAsyncLayer 异步绘制 / 大图滚动降级 / CoreText
- 跨会话全局搜索
- 真监控后台对接（traceId 只打日志）

---

## 二、模块划分

```
Platform/WCIMSDK          ← IM 通用基础设施(新建 Pod)
  Service/  PushService、SyncService(Mock)、SeqIdManager
  Model/    SessionModel、MessageModel(WCDB TableCodable)
  DB/       SessionDB、MessageDB(WCDB)、MessageTableNameRegistry
            DBChangeStream(PassthroughSubject)
  SendQueueManager  ← 跨业务共享的[sessionId: 串行队列]单例

Business/ChatModule       ← 业务侧(MVVM)
  View/   SessionListViewController、ChatDetailViewController、Cells
  Logic/  SessionListLogic、ChatDetailLogic(per session 实例)
          ├ DBObserver  订阅 DBChangeStream
          ├ DBHandler   封装 DB 读取
          ├ SortRuleChain(会话列表)
          └ SendMsgHandler(详情页)
  Model/  SessionCellModel、MessageCellModel(Hashable struct)
```

**依赖方向**：ChatModule → WCIMSDK，WCIMSDK 无任何上游业务依赖。
**职责分离**：WCIMSDK 提供 DB 操作 + Service 通信 + 变更广播；ChatModule 在其上做业务组装。其他业务模块（如 ContactModule 想读最近会话）可自行写轻 Logic 直接访问 WCIMSDK，不依赖 ChatModule。

### ChatModule 目录结构（附录）

按"页面顶层 + 内部 VC/Logic/View/Model 四目录"组织。Phase 标签标注施工归属。

```
Modules/Business/ChatModule/
├── ChatModule.podspec
├── ChatModule.swift                                  # registerRoutes() 入口
│
├── SessionList/                                      # 会话列表页
│   ├── VC/
│   │   └── SessionListViewController.swift          [P1]
│   ├── Logic/
│   │   ├── SessionListLogic.swift                   [P1] # 协调者(@Published + async)
│   │   ├── SessionDBObserver.swift                  [P1] # 订阅 DBChangeStream.sessions
│   │   ├── SessionDBHandler.swift                   [P1] # 封装 SessionDB 读取
│   │   └── SortRule/
│   │       ├── SortRule.swift                       [P1] # protocol + SortRuleChain
│   │       ├── PinnedSortRule.swift                 [P1]
│   │       ├── TimestampSortRule.swift              [P1] # 兜底
│   │       ├── DraftSortRule.swift                  [P3]
│   │       └── UnreadFirstSortRule.swift            [P3]
│   ├── View/
│   │   └── SessionListCell.swift                    [P1]
│   └── Model/
│       └── SessionCellModel.swift                   [P1] # Hashable struct
│
└── ChatDetail/                                       # 聊天详情页
    ├── VC/
    │   └── ChatDetailViewController.swift           [P2]
    ├── Logic/
    │   ├── ChatDetailLogic.swift                    [P2] # 协调者(per session 实例)
    │   ├── MessageDBObserver.swift                  [P2] # 订阅 messagesPublisher(sessionId)
    │   ├── MessageDBHandler.swift                   [P2] # 封装分页/锚定查询
    │   ├── SendMsgHandler.swift                     [P2] # 发送状态机 + 重试
    │   └── MessageRenderCache.swift                 [P3] # 高度 + 富文本缓存
    ├── View/
    │   ├── ChatInputBar.swift                       [P2]
    │   └── Cells/
    │       ├── BaseMessageCell.swift                [P2] # 基类,预留图片/语音子类
    │       └── TextMessageCell.swift                [P2]
    └── Model/
        └── MessageCellModel.swift                   [P2] # Hashable struct
```

**说明**：
- **MessageRenderCache 归入 ChatDetail/Logic/** —— 本质是 Logic 辅助组件（被 MessageDBHandler 调用预计算）
- **SortRule/ 子目录在 Logic 下** —— Rule 子类天然"一类多个"，单独成组
- **每个页面四目录严格对齐 MVVM**：VC = ViewController 入口，View = 子视图/Cell，Logic = 业务，Model = 数据
- **podspec 不用改** —— 用 `**/*.swift` glob，目录嵌套不影响 source_files

---

## 三、架构总览

### 数据单向流动

```
                   ┌──────────────────────────────────────────┐
                   │  Business/ChatModule (MVVM)              │
                   │                                          │
                   │   View ◀──── bind ───── Logic            │
                   │                          │               │
                   │                  subscribe Publisher     │
                   │                  call async command      │
                   └──────────────────│───────│───────────────┘
                                      ▼       ▼
                   ┌──────────────────────────────────────────┐
                   │  Platform/WCIMSDK                        │
                   │                                          │
                   │   Service ──── write ────▶ DB            │
                   │                            │             │
                   │                  事务提交后广播           │
                   │                            ▼             │
                   │                   DBChangeStream         │
                   └──────────────────────────────────────────┘
```

### 收消息链路（Sync 主线）

```
触发源
├─ PushService 收到新消息通知
├─ App 启动 / 前后台切换
├─ SessionListVC.viewDidAppear / ChatDetailVC.viewDidAppear
├─ 网络恢复（NWPathMonitor）
└─ 定时兜底(90s)
        │
        ▼
SyncService.fetchIncremental(after: currentSeqId) → [MessageDTO]
        │
        ▼
WCDB.runTransaction {
   1. 按 sessionId 分组、seqId 增序
   2. for each sessionId:
        MessageTableRegistry.ensureTable(for: sessionId)
        MessageDB.upsert(messages)         ← msgId UNIQUE 自动去重
        SessionDB.upsert(sessionId, lastMsg, unread+N)  ← 聚合,只 update 1 次
   3. 攒事件 pendingSessionEvents / pendingMessageEvents
}
        │
        ▼  事务成功
SeqIdManager.advance(to: lastSeqId)  ← 持久化到 UserDefaults
        │                              事务成功才推进 → 不丢
        ▼
DBChangeStream.publish(pendingEvents)  ← 一次性 flush
        │
        ▼
Logic.DBObserver → SortRuleChain.sort → @Published var sessions
        │
        ▼
View: DiffableDataSource.apply → reconfigureItems(iOS 15+)
```

### 发消息链路（统一也走 DB → UI 单向流）

```
ChatDetailLogic.send(text)
  → 1. 生成 localMsgId(UUID) + traceId(UUID)
  → 2. DB.write { MessageDB.insert(status=.sending); SessionDB.upsert(lastMsg) }
       ↓ DBChangeStream 广播 → UI 立刻显示气泡(发送中)
  → 3. SendQueueManager[sessionId].async {
        retry 3 次,指数退避(1s,2s,4s):
          MockPushService.upload(localMsgId, traceId, payload)
          ↓ 服务端 ACK + serverMsgId + seqId
       成功: DB.write {
         MessageDB.update(localMsgId) {
           $0.msgId = serverMsgId       ← UNIQUE 自动去重后续 Push
           $0.seqId = serverSeqId
           $0.status = .sent
         }
       }
       ↓ UI 刷新成"已发送"
       失败: status = .failed → UI 显示"❗点击重发"
                                 → 重发 localMsgId 不变,服务端按 msgId 幂等
     }
```

**关键点**：发送的 UI 改动也是因 DB 变更而起，符合数据单向流动原则。

---

## 四、WCDB Schema 设计

### SessionDB · 单库单表

```swift
final class SessionModel: TableCodable {
    var sessionId: String         @PrimaryKey
    var contactName: String
    var avatarURL: String?
    var lastMsgId: String?
    var lastMsgPreview: String?   // "[图片]" / "你好" 等预格式化预览
    var lastTimestamp: Int64      @Index    // 排序主键
    var unreadCount: Int
    var isPinned: Bool            @Index    // 置顶排序
    var draft: String?            // 草稿（影响排序优先级）
    var extraJSON: String?        // 业务扩展字段,避免频繁 schema 迁移
}
```

### MessageDB · 每会话一张表（真物理分表）

```swift
final class MessageModel: TableCodable {
    var localMsgId: String        @PrimaryKey   // 端上 UUID,重发不变
    var msgId: String?            @Unique       // 服务端 id,UNIQUE 自动去重
    var sessionId: String         @Index
    var seqId: Int64              @Index        // 排序 + 增量同步锚点
    var senderId: String
    var contentType: Int          // 0=text  (A 档仅支持 text)
    var contentJSON: String       // 各类型 payload 序列化
    var timestamp: Int64
    var status: Int               // 0=sending 1=sent 2=failed 3=received
    var traceId: String?          // 监控追踪
}
```

### 动态表名管理

- 表名规则：`message_{SHA1(sessionId).prefix(16)}`
  - sessionId 由服务端下发，客户端不组装，格式可能为 `"u123-u456"` / `"g_xxx"` / UUID 等
  - Hash 截取保证：长度固定 24 字符内 + 防 SQL 注入 + 兼容任意 sessionId 格式
- 第一条消息到达时按需 `CREATE TABLE IF NOT EXISTS`
- 表名 ↔ sessionId 映射持久化到 `SessionDB.extraJSON`，启动时一次性加载到内存
- 删除会话 → `DROP TABLE` + 删 SessionDB 行 + 移除 Registry 映射

### 物理库划分

```
Sandbox/Documents/IM/{userId}/
  ├─ session.db       ← SessionDB（一张 sessions 表）
  └─ message.db       ← MessageDB（N 张 message_xxx 表）
```

切账号时切目录；卸载/重装/退登能干净清理。

---

## 五、DBChangeStream 设计

写入侧主动广播，不依赖 WCDB hook（写入路径全在 WCIMSDK 内部控制，主动广播比 hook 更可控、能携带语义事件）。

```swift
public final class DBChangeStream {
    public enum SessionEvent {
        case insert([String])   // sessionIds
        case update([String])
        case delete([String])
    }
    public enum MessageEvent {
        case insert(sessionId: String, messages: [MessageModel])
        case update(sessionId: String, messages: [MessageModel])
        case delete(sessionId: String, localMsgIds: [String])
    }

    // 业务侧订阅
    public var sessionsPublisher: AnyPublisher<SessionEvent, Never>
    public func messagesPublisher(of sessionId: String) -> AnyPublisher<MessageEvent, Never>

    // DB 层在事务成功后调用
    func publish(session: SessionEvent)
    func publish(message: MessageEvent)
}
```

**关键约束**：事务成功后再广播。`WCDB.runTransaction` 内部只攒事件，commit 后一次性 flush，避免脏读。

---

## 六、SeqIdManager 设计

```swift
public final class SeqIdManager {
    private let key: String  // "im.seqId.{userId}"
    private let queue = DispatchQueue(label: "seqId.advance")  // 串行,防并发推进
    private(set) var currentSeqId: Int64

    func advance(to seqId: Int64) {
        queue.sync {
            guard seqId > currentSeqId else { return }
            currentSeqId = seqId
            UserDefaults.standard.set(seqId, forKey: key)
        }
    }
}
```

**约束**：DB 事务 commit 后才调用 `advance`；App crash 重启时用旧 seqId 重新拉一包；保证消息不丢。

---

## 七、发送链路设计

### SendQueueManager（WCIMSDK 单例）

```swift
public final class SendQueueManager {
    private var queues: [String: DispatchQueue] = [:]
    private let lock = NSLock()

    func queue(for sessionId: String) -> DispatchQueue {
        lock.lock(); defer { lock.unlock() }
        if let q = queues[sessionId] { return q }
        let q = DispatchQueue(label: "im.send.\(sessionId)")  // 串行
        queues[sessionId] = q
        return q
    }
}
```

- 单会话所有发送串行 → 保证顺序
- 不同会话各走各的队列 → 多会话并发
- 跨 MessageStore 实例共享

### SendMsgHandler 状态机

| 阶段 | DB 写入 | UI 表现 |
|------|---------|---------|
| 创建 | status=sending, localMsgId 生成 | 气泡显示"发送中"圈圈 |
| 上行 ACK 成功 | msgId 回填, seqId 回填, status=sent | "已发送" |
| 重试耗尽 | status=failed | "❗点击重发" |
| 点击重发 | status=sending（localMsgId 不变） | 重新走上行 |

### 服务端二次下发处理

ACK 后服务端可能将同一条消息当"新消息"通过 PushService 下发。`MessageDB.upsert by msgId UNIQUE` 自动 ignore 已存在的，仅触发 `.update` 事件（reconfigure 但 UI 无可见变化）。

---

## 八、会话列表优化

### SortRuleChain · 链表式可插拔排序

```swift
public protocol SortRule {
    /// .orderedSame 时让出给链表下一个规则
    func compare(_ lhs: SessionCellModel, _ rhs: SessionCellModel) -> ComparisonResult
}

public final class SortRuleChain {
    private let rules: [SortRule]   // 链表顺序 = 优先级
    public func sort(_ sessions: [SessionCellModel]) -> [SessionCellModel] { ... }
}

// 业务侧组合(Phase 3 的完整态;Phase 1 只用 PinnedRule + TimestampRule)
let chain = SortRuleChain(rules: [
    PinnedSortRule(),       // 1. 置顶优先
    DraftSortRule(),        // 2. 有草稿的           — Phase 3 加
    UnreadFirstSortRule(),  // 3. 可选：未读优先     — Phase 3 加
    TimestampSortRule(),    // 4. 兜底：时间倒序
])
```

**面试卖点**：新增排序规则只加一个 SortRule 子类，不动既有代码 → 开闭原则。

### DiffableDataSource + reconfigureItems

- `apply(snapshot)` → 框架内部 diff
- 插入/删除 → 自动动画
- 内容更新 → `reconfigureItems`（iOS 15+），直接复用屏幕上的 cell 实例，不走 dequeue
- 滚动中刷新不闪、头像不重下、未读 +1 平滑

### SessionCellModel · Hashable 设计要点

```swift
public struct SessionCellModel: Hashable {
    public let sessionId: String          // 主键
    public let contactName: String
    public let avatarURL: String?
    public let lastMsgPreview: String
    public let formattedTime: String      // 预格式化好
    public let unreadCount: Int
    public let isPinned: Bool

    public func hash(into h: inout Hasher) { h.combine(sessionId) }  // 只用主键

    public static func == (l: Self, r: Self) -> Bool {
        // 比所有展示字段:任何字段变 → diff 触发 reconfigure
    }
}
```

**关键约束**：必须 struct + let。如果 class + mutable 属性，原地改属性 → hash/== 看似没变 → diff 算不出变更 → UI 不刷。

---

## 九、详情页性能 · A 档轻量版

### MessageRenderCache

```swift
public final class MessageRenderCache {
    private struct Entry {
        let height: CGFloat
        let attributedText: NSAttributedString?   // 富文本预排版
    }
    private var storage: [String: Entry] = [:]    // key = localMsgId 或 msgId
    private let lock = NSLock()

    public func height(for key: String) -> CGFloat?
    public func attributedText(for key: String) -> NSAttributedString?
    public func cache(_ entry: Entry, for key: String)
    public func invalidate(_ keys: [String])
}
```

### 预计算策略

DBHandler 分页查 20 条后，在 `DispatchQueue.global()` 批量算 height + attributedText，缓存好再 publish 给 UI；滚动时 `heightForRow` O(1) 读缓存，主线程零计算。

### A 档不做

- YYAsyncLayer 异步绘制气泡
- 大图缩略图 + 滚动降级（A 档仅文本）
- CoreText 直接绘制

---

## 十、Logic 层接口风格

**Combine Publisher（变更流）+ async/await（命令）混合**

```swift
// 订阅变更流
sessionListLogic.sessionsPublisher
    .receive(on: DispatchQueue.main)
    .sink { [weak self] sessions in self?.applySnapshot(sessions) }

// 一次性命令
try await chatDetailLogic.send(text)
try await chatDetailLogic.loadHistory(before: msgId)
```

对齐简历"虚拟人直播间 MVVM + Swift Concurrency + Combine"技术栈，IM 复用同一套。

---

## 十一、迭代路径

### Phase 1 · 会话列表 end-to-end（约 1 周）

**WCIMSDK**
- 新建 Pod，加 WCDB 依赖，podspec / Podfile 集成
- `SessionModel` + `SessionDB`（WCDB schema、按 userId 物理库切换）
- `MessageTableNameRegistry`（SHA1 截取 + SessionDB.extraJSON 持久化映射）
- `DBChangeStream`（PassthroughSubject + 事件类型）
- `MockSyncService.fetchIncremental` 异步吐 100 条假会话变更
- `SeqIdManager`

**ChatModule**
- ❌ 删除 `ChatViewController.swift` / `ChatListCell.swift` / `MockChatData.swift` / `ChatConversation.swift`
- ✅ `SessionCellModel`（Hashable struct）
- ✅ `SessionListLogic`：DBObserver + DBHandler + SortRuleChain（PinnedRule + TimestampRule 兜底）
- ✅ `SessionListViewController`：DiffableDataSource + reconfigureItems

**主工程**
- ✅ `MainTabBarController.setupViewControllers()` 把 `ChatViewController()` 替换为 `SessionListViewController()`
  - 会话列表是 TabBar root，外部不需要跳转，不必加 Routes 路由常量
- `ChatModule.registerRoutes()` Phase 1 阶段保持空,Phase 2 才注册 chatDetail

**验证**：启动看到 100 个会话，MockSync 5 秒后追加 1 个会话变更，列表平滑增量刷新。

### Phase 2 · 详情页 + 发送链路（约 1 周）

**WCIMSDK**
- `MessageModel` + `MessageDB`（动态建表、upsert、分页查询）
- `SendQueueManager`（[sessionId: 串行队列]）
- `MockPushService.upload`（模拟 500ms 后 ACK，10% 概率失败）
- MockSyncService 扩展支持拉消息（不只是会话）

**ChatModule**
- `MessageCellModel`
- `ChatDetailLogic`（per session 实例）：DBObserver + DBHandler（分页）+ SendMsgHandler
- `ChatDetailViewController`（原生实现，替代原 RN 页面）
- `Routes.chatDetail` URL 改为 `wechat://chat/detail`
- `ChatModule.registerRoutes()` 注册 `ChatDetailViewController.registerPageRoute()`
- WeChatRN 里 RN 那边的 chat 页面代码保留作为 RN 能力对照，不动

**验证**：发 10 条消息，能看到串行排队、ACK 后状态翻转、失败时点重发 localMsgId 不变。

### Phase 3 · 横切补强（约 3~5 天）

- `MessageRenderCache`（高度 + 富文本预计算，后台线程）
- 会话列表批量聚合优化（已在 Sync 设计，验证大批量变更只 reconfigure 一次）
- 更多 SortRule（DraftRule、UnreadFirstRule）演示可插拔
- 触发源完善（前后台切换、网络恢复、定时兜底 90s）
- traceId 打日志闭环（不接监控后台）
- 仓库根目录加 README + 架构图，方便面试官看

**验证**：完整 demo 视频；功能闭环；能在 README 里讲清楚链路。

---

## 十二、B 档未来演进清单（不实现，但记录）

| 未来项 | 面试话术 |
|---|---|
| 真 WebSocket + 弱网重连 | "骨架里 PushService/SyncService 是 mock，可以无缝替换成真长连接" |
| YYAsyncLayer 异步绘制 | "高度和富文本已预算，下一步把 layer.display 也搬子线程" |
| 大图缩略图 + 滚动降级 | "目前文本消息，加入图片消息后做大图懒加载和滚动取消" |
| 富文本引用 / @ 人解析 | "MessageRenderCache 接口已支持 attributedText，扩展只在 Cache 层加解析" |
| traceId 完整链路监控 | "已生成 traceId 打日志，下一步对接监控聚合做端到端到达率" |
| 跨会话全局搜索 | "需 UNION ALL 拼所有 message_xxx 表，单独 SearchService" |

---

## 十三、风险与缓解

| 风险 | 缓解 |
|---|---|
| 动态表名 SQL 注入 | 严禁拼接 sessionId 原文，必须走 MessageTableNameRegistry（hash 截取） |
| Sync 期间 App crash 导致 seqId 推进过早 | DB 事务 commit 后才 advance，重启用旧 seqId 重拉 |
| Phase 1 重写阻塞现有路由 | ChatViewController 直接删，同步改 MainTabBarController.setupViewControllers() 替换为 SessionListVC，编译不留空窗 |
| MockSyncService 与未来真 Service 接口偏移 | Service 层用 protocol，Mock 与未来 Real 实现同一协议 |
| WCDB 主线程读写阻塞 | DBHandler 所有读写在专用 queue，UI 通过 Publisher 异步收 |

---

## 十四、测试策略（A 档基本款）

- **单元测试**：SortRuleChain（链表优先级行为）、SeqIdManager（并发推进）、MessageTableNameRegistry（hash 稳定性 + 防注入）
- **集成测试**：MockSyncService 灌 N 条消息 → 断言 SessionDB / MessageDB 落库 + DBChangeStream 事件数量
- **手动验证**：完整 demo 视频，覆盖 Phase 1/2/3 各阶段验证点
