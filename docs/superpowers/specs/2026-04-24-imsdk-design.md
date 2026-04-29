# IMSDK 设计文档 — 基于微信 Sync 机制的企业级 IM SDK

## 一、概述

### 1.1 定位

纯客户端 IM SDK，基于微信 sync 机制实现消息同步。服务端能力通过 mock 提供，但客户端接口按真实对接标准设计，未来替换 mock 层即可接入真实服务端。

### 1.2 目标

- 完整设计覆盖：消息收发、会话管理、联系人、群组、多媒体消息、消息撤回/已读、@提醒、全文搜索、多设备同步
- 实现上从最小可用（Phase 1）开始迭代

### 1.3 约束

| 维度 | 决策 |
|------|------|
| 平台 | iOS only，Swift |
| 最低版本 | iOS 15.1+ |
| 代码组织 | 本地 Pod（Foundation/IMSDK） |
| 对外 API | async/await + AsyncSequence |
| 内部事件分发 | Combine（对外包装为 AsyncStream） |
| 持久化 | WCDB + SQLCipher 加密 |
| 长连接 | WebSocket（协议层抽象，可替换） |
| 序列化 | JSON + Codable |
| 消息类型 | 枚举封闭式 |
| 线程模型 | 混合（Actor 保护状态 + async/await 编排流程） |
| 多账号 | 支持，工厂模式，每个 IMClient 实例独立 |
| 加密 | TLS 传输加密 + WCDB 本地加密（SQLCipher） |
| 多媒体 | SDK 管流程，业务注入上传通道（IMFileUploader 协议） |
| 日志 | SDK 内置分级日志，暴露 logHandler 给业务层 |
| 会话模型 | 独立维度，conversations 表独立于消息表 |
| 群规模 | 小群（500 人以内），架构预留大群口子 |
| 消息存储 | 分表，每个会话一张消息表 |

---

## 二、整体架构

### 2.1 四层架构

```
┌─────────────────────────────────────────────────────┐
│            业务层（WeChatSwift）                      │
│         通过 IMClient 公共 API 接入                   │
└──────────────────────┬──────────────────────────────┘
                       │ async/await + AsyncStream
┌──────────────────────▼──────────────────────────────┐
│  Interface 层（对外 API）                             │
│  IMClient / IMConfig / IMEvent                      │
│  ─ 工厂模式入口，每个实例独立                          │
│  ─ 对外暴露 async/await 操作 + AsyncStream 事件流     │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│  Engine 层（核心引擎）                                │
│  ┌─────────────┐ ┌──────────────┐ ┌──────────────┐  │
│  │ SyncEngine  │ │ MessageEngine│ │ SessionEngine│  │
│  │ sync 协议    │ │ 收发/状态机   │ │ 会话管理      │  │
│  └──────┬──────┘ └──────┬───────┘ └──────┬───────┘  │
│  ┌──────┴──────┐ ┌──────┴───────┐ ┌──────┴───────┐  │
│  │ContactEngine│ │ GroupEngine  │ │ MediaEngine  │  │
│  │ 联系人管理   │ │ 群组管理      │ │ 多媒体流程    │  │
│  └─────────────┘ └──────────────┘ └──────────────┘  │
│  ┌─────────────┐                                     │
│  │SearchEngine │                                     │
│  │ 全文搜索     │                                     │
│  └─────────────┘                                     │
└──────────────────────┬──────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────┐
│  Infrastructure 层（基础设施）                         │
│  ┌─────────────┐ ┌──────────────┐ ┌──────────────┐  │
│  │ Connection   │ │    Store     │ │   Logger     │  │
│  │ WebSocket    │ │   WCDB       │ │  分级日志     │  │
│  │ + 重连/心跳   │ │ + SQLCipher  │ │              │  │
│  └─────────────┘ └──────────────┘ └──────────────┘  │
│  ┌─────────────┐ ┌──────────────┐                    │
│  │  Codec       │ │ FileUploader │                    │
│  │ JSON 编解码   │ │ 协议，业务注入 │                    │
│  └─────────────┘ └──────────────┘                    │
└─────────────────────────────────────────────────────┘
```

### 2.2 核心原则

- 依赖单向向下，上层不知道下层实现细节
- Engine 层是 SDK 的大脑，编排所有业务逻辑
- Infrastructure 层全部面向协议，可替换
- 每个 IMClient 实例持有独立的 Engine + Infrastructure，多账号完全隔离

---

## 三、Sync 引擎

### 3.1 Sync 机制概述

- 服务端维护单调递增的 syncKey，每次有新数据（消息、联系人变更、设置变更等）syncKey 递增
- 客户端记住最后同步到的 syncKey，通过 `sync(lastSyncKey)` 拉取增量数据
- 长连接 notify：服务端有新数据时通过 WebSocket 推送通知（不携带具体数据），客户端收到后主动发起 sync
- 多种数据类型统一同步：消息、联系人变更、会话更新等都通过同一个 sync 通道，用 cmdId 区分

### 3.2 Sync 流程

```
Server(WebSocket)         SyncEngine              Store(WCDB)
     │                        │                        │
     │  ① notify              │                        │
     │  {"type":"sync"}       │                        │
     │───────────────────────>│                        │
     │                        │  ③ 读取本地 syncKey      │
     │  ② sync request        │───────────────────────>│
     │  syncKey=1024          │                        │
     │<───────────────────────│                        │
     │                        │                        │
     │  ④ sync response       │                        │
     │  newKey=1030           │                        │
     │  cmdList: [...]        │                        │
     │───────────────────────>│                        │
     │                        │  ⑤ 事务写入              │
     │                        │───────────────────────>│
     │                        │  ⑥ 更新 syncKey         │
     │                        │───────────────────────>│
     │                        │  ⑦ 发布事件              │
     │                        │──> EventBus            │
     │                        │  ⑧ hasMore → 回②       │
```

### 3.3 Sync 数据模型

```swift
struct SyncRequest: Codable {
    let syncKey: Int64
    let limit: Int
}

struct SyncResponse: Codable {
    let newSyncKey: Int64
    let hasMore: Bool
    let cmdList: [SyncCommand]
}

struct SyncCommand: Codable {
    let cmdId: Int
    let data: SyncCommandData
}

enum SyncCommandData: Codable {
    case newMessage(Message)
    case messageUpdate(MessageUpdate)
    case conversationUpdate(Conversation)
    case contactUpdate(Contact)
    case groupUpdate(Group)
    case groupMemberUpdate(GroupMemberChange)
}
```

### 3.4 状态机

```
         connect()
  IDLE ──────────> WAITING
   ^                  │
   │                  │ 收到 notify
   │                  v
   │              SYNCING ──┐
   │                  │     │ hasMore=true
   │                  │<────┘
   │   hasMore=false  │
   │                  v
   │              PROCESSING
   │                  │
   └──────────────────┘
        写入完成，回到 WAITING
```

### 3.5 关键设计决策

1. **Sync 串行**：同一时间只有一个 sync 流程在跑，通过单一 Task 驱动 sync 循环
2. **写入和 syncKey 更新在同一事务中**：崩溃恢复后不会丢数据也不会重复处理
3. **首次登录全量同步**：syncKey=0 时服务端返回全量数据，通过 hasMore 分批拉取
4. **重连后增量同步**：用本地 syncKey 拉增量，和正常 sync 一致

---

## 四、连接管理与重连策略

### 4.1 连接协议抽象

```swift
protocol IMConnection {
    func connect() async throws
    func disconnect()
    func send(_ data: Data) async throws
    var receivedData: AsyncStream<Data> { get }
    var state: AsyncStream<ConnectionState> { get }
}

enum ConnectionState {
    case disconnected(reason: DisconnectReason)
    case connecting
    case connected
    case reconnecting(attempt: Int)
}

enum DisconnectReason {
    case initial
    case manual
    case networkLost
    case serverClose
    case heartbeatTimeout
    case authFailure
    case kicked
}
```

### 4.2 心跳机制

- 每 30 秒发送 ping
- 10 秒内未收到 pong 判定连接死亡
- 触发重连

### 4.3 重连策略 — 指数退避 + 网络感知

```
第 1 次: 立即（0s）
第 2 次: 2s
第 3 次: 4s
第 4 次: 8s
第 5 次: 16s
后续:   30s 封顶 + 随机抖动
网络状态变化 → 立即重连，重置计数器
```

### 4.4 不重连场景

| 场景 | 行为 |
|------|------|
| 网络抖动 / 心跳超时 | 重连 |
| 服务端主动关闭 | 重连 |
| 主动 disconnect() | 不重连 |
| 鉴权失败 | 不重连，抛事件 |
| 被踢下线 | 不重连，抛事件 |

### 4.5 前后台切换

- 进入后台：保持连接 60 秒，之后系统挂起连接断开
- 回到前台：检测连接状态，断开则立即重连，重连成功后 sync 增量数据

---

## 五、数据模型与存储设计

### 5.1 核心数据模型

```swift
// 消息
struct Message: Codable {
    let messageId: String
    let conversationId: String
    let sender: String
    let content: MessageContent
    let timestamp: Int64
    var status: MessageStatus
    var serverMsgId: Int64?
    var extra: MessageExtra?
}

enum MessageContent: Codable {
    case text(String)
    case image(ImageInfo)
    case voice(VoiceInfo)
    case video(VideoInfo)
    case file(FileInfo)
    case location(LocationInfo)
    case richText(RichTextContent)   // 带 @ 的文本
    case system(String)
}

enum MessageStatus: Int, Codable {
    case sending = 0
    case sent = 1
    case delivered = 2
    case read = 3
    case failed = -1
    case recalled = -2
}

struct MessageExtra: Codable {
    var editCount: Int?
    var replyToMsgId: String?
    var mentions: [String]?
}

// 会话
struct Conversation: Codable {
    let conversationId: String
    let type: ConversationType
    var title: String
    var avatar: String?
    var lastMessage: Message?
    var lastMessageTime: Int64
    var unreadCount: Int
    var isPinned: Bool
    var isMuted: Bool
    var draft: String?
    var sortKey: Int64
    var mentionInfo: MentionInfo?
}

enum ConversationType: Int, Codable {
    case single = 0
    case group = 1
}

// 联系人
struct Contact: Codable {
    let userId: String
    var nickname: String
    var avatar: String?
    var remark: String?
    var pinyin: String?
    var isFriend: Bool
    var isBlocked: Bool
}

// 群组
struct Group: Codable {
    let groupId: String
    var name: String
    var avatar: String?
    var ownerId: String
    var announcement: String?
    var memberCount: Int
    var isAllMute: Bool
}

struct GroupMember: Codable {
    let groupId: String
    let userId: String
    var nickname: String
    var role: GroupRole
}

enum GroupRole: Int, Codable {
    case member = 0
    case admin = 1
    case owner = 2
}

// @ 提醒
struct RichTextContent: Codable {
    let text: String
    let mentions: [Mention]
}

struct Mention: Codable {
    let userId: String
    let nickname: String
    let offset: Int
    let length: Int
}

struct MentionInfo: Codable {
    let type: MentionType
    let messageId: String
}

enum MentionType: Int, Codable {
    case me = 1
    case all = 2
}
```

### 5.2 数据库 Schema

每个账号独立数据库文件：`im_{userId}.db`，SQLCipher 加密，key 存 Keychain。

**分表策略**：消息按会话分表，每个会话一张消息表。其余为全局表。

```
固定表（6张）:
  ├── conversations        会话表
  ├── contacts             联系人表
  ├── groups               群组表
  ├── group_members        群成员表
  ├── sync_state           同步状态表
  ├── pending_tasks        离线操作队列表
  └── fts_messages         FTS5 全文索引表

动态表（N张）:
  └── msg_{convId_hash}    每个会话一张消息表（convId_hash = conversationId 的 MD5 前 16 位）
```

#### conversations 表

| 字段 | 类型 | 说明 |
|------|------|------|
| conversation_id | TEXT PK | 会话 ID |
| type | INT | 0=单聊 1=群聊 |
| title | TEXT | 标题 |
| avatar | TEXT | 头像 URL |
| last_msg_id | TEXT | 最后一条消息 ID |
| last_msg_time | INT INDEX | 最后消息时间 |
| last_msg_summary | TEXT | 最后消息摘要 |
| unread_count | INT | 未读数 |
| is_pinned | INT | 是否置顶 |
| is_muted | INT | 是否免打扰 |
| draft | TEXT | 草稿 |
| sort_key | INT INDEX | 排序键 |
| mention_type | INT | @类型 |
| mention_msg_id | TEXT | @消息ID |
| extra | TEXT | JSON 扩展字段 |

#### msg_{convId_hash} 表（每个会话一张）

| 字段 | 类型 | 说明 |
|------|------|------|
| message_id | TEXT PK | 消息 ID |
| sender | TEXT | 发送者 |
| content_type | INT | 消息类型 |
| content_json | TEXT | 消息内容 JSON |
| timestamp | INT INDEX | 时间戳 |
| status | INT | 消息状态 |
| server_msg_id | INT | 服务端序列号 |
| extra | TEXT | JSON 扩展字段 |

#### contacts 表

| 字段 | 类型 | 说明 |
|------|------|------|
| user_id | TEXT PK | 用户 ID |
| nickname | TEXT | 昵称 |
| avatar | TEXT | 头像 URL |
| remark | TEXT | 备注名 |
| pinyin | TEXT INDEX | 排序用 |
| is_friend | INT | 是否好友 |
| is_blocked | INT | 是否拉黑 |

#### groups 表

| 字段 | 类型 | 说明 |
|------|------|------|
| group_id | TEXT PK | 群 ID |
| name | TEXT | 群名 |
| avatar | TEXT | 群头像 |
| owner_id | TEXT | 群主 |
| announcement | TEXT | 群公告 |
| member_count | INT | 成员数 |
| is_all_mute | INT | 全员禁言 |

#### group_members 表

| 字段 | 类型 | 说明 |
|------|------|------|
| group_id | TEXT | 群 ID（联合主键） |
| user_id | TEXT | 用户 ID（联合主键） |
| nickname | TEXT | 群昵称 |
| role | INT | 角色 |

#### sync_state 表

| 字段 | 类型 | 说明 |
|------|------|------|
| key | TEXT PK | 键名 |
| value | TEXT | 值（syncKey、lastSyncTime 等） |

#### pending_tasks 表

| 字段 | 类型 | 说明 |
|------|------|------|
| task_id | TEXT PK | 任务 ID |
| type | INT | 类型（send_msg/recall/mark_read） |
| payload | TEXT | JSON 载荷 |
| status | INT | 状态 |
| retry_count | INT | 重试次数 |
| created_at | INT | 创建时间 |

#### fts_messages 表（FTS5 虚拟表）

| 字段 | 类型 | 说明 |
|------|------|------|
| message_id | TEXT | 消息 ID |
| conversation_id | TEXT | 会话 ID |
| searchable_text | TEXT | 可搜索文本 |

### 5.3 Schema 兼容性设计

- `extra` JSON 扩展字段：80% 的新增字段通过 extra 存放，不需要 ALTER TABLE
- 枚举用 Int 存储：新增枚举值不改表
- content 拆 type + json：新增消息类型不改表
- WCDB 版本化迁移兜底：真需要改表时有标准流程

---

## 六、事件系统与 API 设计

### 6.1 事件体系

```swift
enum IMEvent {
    // 连接状态
    case connectionStateChanged(ConnectionState)

    // 消息
    case messagesReceived([Message])
    case messageStatusUpdated(messageId: String, status: MessageStatus)
    case messageRecalled(messageId: String, conversationId: String)
    case messageEdited(Message)

    // 会话
    case conversationUpdated(Conversation)
    case conversationDeleted(conversationId: String)
    case unreadCountChanged(total: Int)

    // 联系人
    case contactUpdated(Contact)
    case contactDeleted(userId: String)

    // 群组
    case groupUpdated(Group)
    case groupMemberChanged(groupId: String, change: GroupMemberChange)

    // Sync
    case syncStarted
    case syncCompleted

    // 被踢下线
    case kicked(reason: String)
}
```

### 6.2 事件分发

内部 Combine PassthroughSubject 多播，对外每次访问 `.events` 生成独立 AsyncStream，支持多订阅者。

### 6.3 IMClient API

```swift
public class IMClient {

    // 初始化
    init(config: IMConfig)

    // 生命周期
    func login(userId: String, token: String) async throws
    func logout() async

    // 事件流
    var events: AsyncStream<IMEvent> { get }
    var messageEvents: AsyncStream<IMEvent> { get }
    var connectionState: AsyncStream<ConnectionState> { get }

    // 消息
    func send(_ content: MessageContent, to conversationId: String) async throws -> Message
    func resend(messageId: String) async throws -> Message
    func recall(messageId: String) async throws
    func markAsRead(conversationId: String) async throws
    func getMessages(conversationId: String, before: Int64?, limit: Int) async throws -> [Message]
    func searchMessages(keyword: String) async throws -> [Message]

    // 会话
    func getConversations() async throws -> [Conversation]
    func deleteConversation(_ id: String) async throws
    func pinConversation(_ id: String, pin: Bool) async throws
    func muteConversation(_ id: String, mute: Bool) async throws
    func saveDraft(_ id: String, draft: String?) async throws
    func getTotalUnreadCount() async throws -> Int

    // 联系人
    func getContacts() async throws -> [Contact]
    func getContact(userId: String) async throws -> Contact
    func setRemark(userId: String, remark: String) async throws
    func blockContact(userId: String, block: Bool) async throws
    func addFriend(userId: String, message: String) async throws
    func deleteFriend(userId: String) async throws

    // 群组
    func createGroup(name: String, memberIds: [String]) async throws -> Group
    func getGroup(groupId: String) async throws -> Group
    func getGroupMembers(groupId: String) async throws -> [GroupMember]
    func addGroupMembers(groupId: String, userIds: [String]) async throws
    func removeGroupMember(groupId: String, userId: String) async throws
    func updateGroupName(groupId: String, name: String) async throws
    func quitGroup(groupId: String) async throws
    func dismissGroup(groupId: String) async throws

    // 多媒体
    func downloadMedia(message: Message) async throws -> URL
    func cancelDownload(messageId: String)

    // 配置
    static var logLevel: IMLogLevel
    static var logHandler: ((IMLogLevel, String) -> Void)?
}

public struct IMConfig {
    let wsURL: URL
    let dbDirectory: URL?
    let dbEncryptionKey: String?
    let fileUploader: IMFileUploader?
    let heartbeatInterval: TimeInterval   // 默认 30s
    let reconnectMaxDelay: TimeInterval   // 默认 30s
}
```

---

## 七、消息收发流程与状态机

### 7.1 发送消息流程

1. 构造 Message，status = .sending
2. 事务写入本地（消息分表 + conversations + pending_tasks + fts_messages）
3. 发布事件，UI 立即展示发送中气泡
4. 通过 WebSocket 发送，成功则 status = .sent 并删除 pending_task；失败则 status = .failed，pending_task 保留等重连重试
5. return Message

### 7.2 接收消息流程

1. sync 收到 newMessage 类型 SyncCommand
2. 通过 serverMsgId 去重，已存在则跳过
3. 事务写入（消息分表 + conversations + fts_messages）
4. 发布事件（messagesReceived + conversationUpdated + unreadCountChanged）

### 7.3 消息状态机

```
        send()
          │
          ▼
      ┌────────┐   ack    ┌──────┐  对方收到  ┌───────────┐
      │sending │────────>│ sent │──────────>│ delivered │
      └────┬───┘          └──────┘           └─────┬─────┘
           │                                       │
           │ 失败                              对方已读│
           ▼                                       ▼
      ┌────────┐  resend  ┌──────┐           ┌──────┐
      │ failed │────────>│sending│           │ read │
      └────────┘          └──────┘           └──────┘

      任何状态 → recall() → recalled
```

### 7.4 离线操作队列（pending_tasks）

- 离线时的发消息、撤回、标已读等操作写入 pending_tasks
- 重连成功后按 created_at 顺序重试
- 重试 3 次仍失败则标记失败并删除任务

### 7.5 消息撤回

- 发起方：本地 status = recalled，content 替换为提示文案，通知服务端
- 接收方：通过 sync 收到 messageRecalled，本地同样处理

### 7.6 已读回执

- 进入会话详情页调 markAsRead
- 本地 unreadCount = 0，通知服务端
- 服务端通过 sync 通知对方，对方更新消息状态

---

## 八、多媒体消息处理

### 8.1 架构

```
MediaEngine
  ├── MediaPreprocessor   压缩/缩略图/转码
  ├── IMFileUploader      协议，业务注入上传通道
  ├── MediaDownloader     下载管理
  └── CacheManager        二级缓存（内存 LRU + 磁盘）
```

### 8.2 发送图片流程

1. Preprocessor 预处理：生成缩略图 + 压缩原图 + 提取元信息
2. 构造消息（url 为空），写入本地，UI 用 localPath 展示
3. 调用 IMFileUploader 上传缩略图和压缩图
4. 上传成功后发送消息到服务端（携带 url）
5. 更新本地消息，删除 pending_task

### 8.3 各类型预处理

| 类型 | 预处理 | 上传物 |
|------|-------|--------|
| 图片 | 压缩 + 缩略图 | 原图 + 缩略图 |
| 语音 | 转码 AAC + 计算时长 | 音频文件 |
| 视频 | 压缩 + 首帧缩略图 + 计算时长 | 视频 + 首帧图 |
| 文件 | 无 | 原文件 |
| 位置 | 无 | 无上传 |

### 8.4 IMFileUploader 协议

```swift
public protocol IMFileUploader {
    func upload(data: Data, type: IMFileType,
                progress: @Sendable (Double) -> Void) async throws -> URL
}
```

### 8.5 缓存策略

- 内存：NSCache，50MB 上限
- 磁盘：500MB 上限，超限按 LRU 清理
- 缩略图常驻不清理，原图/视频按 LRU 淘汰

---

## 九、多设备同步与冲突处理

### 9.1 核心原则

服务端是唯一真相源。每个设备维护独立 syncKey，所有写操作先发服务端，通过 sync 机制分发到各设备。

### 9.2 自己发的消息处理

本地先写入 status=sending 展示，收到 ack 后更新。下次 sync 回来的同一条消息通过 serverMsgId 去重跳过。

### 9.3 冲突处理策略

| 原则 | 说明 |
|------|------|
| 服务端权威 | 所有冲突以服务端状态为准 |
| Last Write Wins | 会话属性（置顶/免打扰等）取最后写入 |
| Max Wins | 已读状态取最大值，不倒退 |
| serverMsgId 去重 | 同一条消息不会重复入库 |
| serverMsgId 排序 | 消息顺序以服务端序列号为准 |
| 幂等 sync | 重复处理同一批数据不产生副作用 |

---

## 十、搜索

### 10.1 全局搜索

走 FTS5 全文索引表 `fts_messages`，写消息时同步维护。搜索命中后用 message_id 回分表取完整消息，按会话分组返回结果。

### 10.2 会话内搜索

直接查对应会话的分表 `msg_{convId_hash}`，走 LIKE 匹配。

---

## 十一、@ 提醒

- 带 @ 的消息使用 `.richText(RichTextContent)` 类型，携带 mentions 列表
- 接收时检查 mentions 是否包含当前 userId 或 @all
- 命中则更新 conversation.mentionInfo，会话列表展示 "[有人@我]"
- 用户进入会话后清除 mentionInfo

---

## 十二、Pod 工程结构

```
Foundation/IMSDK/
  IMSDK.podspec
  Sources/
    ├── Public/                   对外 API
    │   ├── IMClient.swift
    │   ├── IMConfig.swift
    │   ├── IMEvent.swift
    │   ├── Models/
    │   │   ├── Message.swift
    │   │   ├── MessageContent.swift
    │   │   ├── Conversation.swift
    │   │   ├── Contact.swift
    │   │   ├── Group.swift
    │   │   └── GroupMember.swift
    │   └── Protocols/
    │       ├── IMFileUploader.swift
    │       └── IMConnection.swift
    │
    ├── Engine/                   核心引擎
    │   ├── SyncEngine.swift
    │   ├── MessageEngine.swift
    │   ├── ConversationEngine.swift
    │   ├── ContactEngine.swift
    │   ├── GroupEngine.swift
    │   ├── MediaEngine.swift
    │   └── SearchEngine.swift
    │
    ├── Connection/               连接层
    │   ├── WebSocketConnection.swift
    │   ├── ConnectionManager.swift
    │   ├── HeartbeatManager.swift
    │   └── ReconnectPolicy.swift
    │
    ├── Store/                    存储层
    │   ├── IMDatabase.swift
    │   ├── MessageStore.swift
    │   ├── ConversationStore.swift
    │   ├── ContactStore.swift
    │   ├── GroupStore.swift
    │   ├── SyncStateStore.swift
    │   ├── PendingTaskStore.swift
    │   └── Models/
    │       ├── DBMessage.swift
    │       ├── DBConversation.swift
    │       ├── DBContact.swift
    │       ├── DBGroup.swift
    │       └── DBGroupMember.swift
    │
    ├── Media/                    多媒体处理
    │   ├── MediaPreprocessor.swift
    │   ├── MediaDownloader.swift
    │   └── CacheManager.swift
    │
    ├── Util/                     内部工具
    │   ├── IMLogger.swift
    │   └── IMError.swift
    │
    └── State/                    Actor 状态
        └── ConnectionState.swift
```

依赖：`WCDBSwift ~> 2.1`，系统框架 Foundation / Combine / Network。

---

## 十三、分阶段实现计划

| 阶段 | 内容 | 可运行标志 |
|------|------|-----------|
| Phase 1 | IMClient 骨架 + WebSocket 连接 + 心跳 + 重连 | 能连上 mock server，保持心跳 |
| Phase 2 | SyncEngine + WCDB 存储 + syncKey 管理 | 能 sync 到数据并持久化 |
| Phase 3 | 消息收发 + 会话管理 + pending_tasks | 能发消息、收消息、看会话列表 |
| Phase 4 | 联系人 + 群组 | 能查联系人、建群、群消息 |
| Phase 5 | 多媒体消息 + 缓存 | 能发图片/语音/视频 |
| Phase 6 | 撤回 / 已读 / @提醒 | 高级消息特性 |
| Phase 7 | 全文搜索 + 多设备同步 | 功能完备 |
| Phase 8 | Mock Server | Node.js WebSocket server，完整 sync 协议 |
