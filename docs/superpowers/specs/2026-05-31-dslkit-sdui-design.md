# DSLKit — 动态化页面引擎(SDUI)设计文档

**日期**:2026-05-31
**作者**:nicedayzhu(+ AI pair)
**状态**:设计待评审

---

## 1. 目标(Goal)

构建一套 **DSL/JSON 驱动的动态页引擎(Server-Driven UI)**:页面用 JSON 描述 → 客户端原生渲染 → 走 OSS 热更新,无需发版即可改页面。

**首发试验田**:「我的」页(MeViewController)—— 低频、风险小、标准列表型。头部 + 菜单列表**整页** DSL 化。

**一句话价值**:在原生与 RN/H5 之间补上「**比原生灵活、比 RN/H5 轻**」的动态化中间层,点亮大厂核心能力——动态化 / SDUI / DSL。

---

## 2. 为什么本项目适合(现有资产复用)

| 已有资产 | 复用为 |
|---|---|
| `GameBundleManager`(下载+版本+sha256+灰度+回滚) | `PageSchemaManager`(页面 schema 下发管理,照搬模式) |
| OSS manifest 热更通道 | 页面 manifest + schema 下发 |
| `WeChatRouter`(`wechat://` 路由) | DSL action 分发 + `wechat://page/{id}` 路由到 DSL 页 |
| `WeChatUI` 基础组件 / `ExtensionKit` UIColor(hex:) | DSL 组件底层实现 |
| IM 的 DiffableDataSource 经验 | DSL 列表渲染 |
| 游戏大厅 manifest 驱动 | SDUI 的雏形(已走一半) |

---

## 3. 架构(Architecture)

### 3.1 模块归属

新建 **`DSLKit`**(Platform 层,`Modules/WeChatKit/DSLKit`)。依赖:`WeChatUI`、`WeChatRouter`、`NavigateKit`、`ExtensionKit`、`SnapKit`、`ZIPFoundation`(若 schema 走 zip;Phase 1 用裸 JSON 可不依赖)。

MeModule 改为消费 DSLKit。引擎与业务解耦,后续发现页 / 活动页 / IM 卡片均可复用。

### 3.2 四层结构

```
DSLPage / DSLNode (Codable)          ← ① 模型层:JSON → 强类型节点树
        ↓
DSLComponentRegistry                 ← ② 注册表:type → builder(可扩展、向前兼容)
   profileHeader / group / cell / spacer …
        ↓
DSLRenderer                          ← ③ 渲染器:节点树 → insetGrouped UITableView
        ↓
DSLActionHandler                     ← ④ 动作层:action 字符串 → Router.shared.push / 埋点
```

容器:`DSLPageViewController(pageId:)` —— 拉 schema → 渲染 → 处理交互。

### 3.3 DSL 协议(Schema v1)

```json
{
  "page": "me",
  "version": "1.0",
  "minClient": 1,
  "background": "#F2F3F5",
  "sections": [
    { "type": "profileHeader",
      "name": "用户", "wxid": "微信号 wxid_demo",
      "status": "状态 · 今天也在认真生活",
      "avatarText": "我", "avatarColor": "#07C160",
      "action": "wechat://rn?page=profile" },

    { "type": "group", "children": [
      { "type": "cell", "icon": "creditcard.fill", "iconColor": "#576B95",
        "title": "服务", "action": "wechat://rn?page=services" }
    ]},

    { "type": "group", "children": [
      { "type": "cell", "icon": "star.fill", "iconColor": "#FA9D3B", "title": "收藏", "action": "wechat://rn?page=favorites" },
      { "type": "cell", "icon": "photo.on.rectangle.fill", "iconColor": "#07C160", "title": "朋友圈", "action": "wechat://rn?page=moments" },
      { "type": "cell", "icon": "menucard.fill", "iconColor": "#576B95", "title": "卡包", "action": "wechat://rn?page=cards" },
      { "type": "cell", "icon": "face.smiling.fill", "iconColor": "#FA9D3B", "title": "表情", "action": "wechat://rn?page=stickers" }
    ]},

    { "type": "group", "children": [
      { "type": "cell", "icon": "gearshape.fill", "iconColor": "#576B95", "title": "设置", "action": "wechat://rn?page=settings" }
    ]}
  ]
}
```

**四要素**:组件 `type` / 属性(props,平铺在节点上)/ 子节点 `children` / 动作 `action`。

**Phase 1 组件清单**
- `profileHeader`:头像(文字或图)+ 昵称 + wxid + 状态 pill + 二维码箭头;点击 → action
- `group`:一个 insetGrouped 分组卡,`children` 为 cell
- `cell`:`icon`(SF Symbol 名)+ `iconColor`(hex)+ `title` + 可选 `badge` / `rightText` + `action`
- `spacer`:可选间距

### 3.4 模型层

```swift
public struct DSLPage: Codable {
    public let page: String
    public let version: String
    public let minClient: Int?
    public let background: String?
    public let sections: [DSLNode]
}

public struct DSLNode: Codable {
    public let type: String
    public let children: [DSLNode]?
    // 其余属性用一个宽松容器装,渲染器按需取
    public let props: [String: DSLValue]   // 自定义 Codable,支持 string/int/bool
    public var action: String? { props["action"]?.stringValue }
}
```
> `DSLValue` 为 `enum { case string/int/double/bool }` 的 Codable 包装,容忍未知字段(向前兼容关键)。

### 3.5 注册表 + 渲染器

```swift
public protocol DSLComponent {
    static var type: String { get }
    // 返回该节点对应的「行模型」或直接构建 cell/view
}
public final class DSLComponentRegistry {
    public static let shared = DSLComponentRegistry()
    public func register(_ type: String, builder: @escaping (DSLNode) -> DSLRow)
    public func build(_ node: DSLNode) -> DSLRow?   // 未知 type → nil(跳过,不崩)
}
```

`DSLRenderer`:把 sections 展平成 `[DSLSection]`(每个 group → 一个 table section,profileHeader → tableHeaderView 或独立 section),用 **insetGrouped UITableView** 渲染。cell 复用泛化后的 `DSLMenuCell`(由现 `MeMenuCell` 提炼)。

### 3.6 动作层

```swift
public enum DSLAction {
    static func handle(_ raw: String?) {
        guard let raw, let url = URL(string: raw) else { return }
        // 埋点钩子(可选)
        Router.shared.push(raw)   // 复用现有路由
    }
}
```

### 3.7 热更通道:`PageSchemaManager`(照搬 GameBundleManager)

- **manifest**:`pages/manifest.json` → `{ pageId: {url, version, sha256, grayscale} }`
- **流程**:启动拉取 → sha256 校验 → 缓存到 `Documents/Pages/` → 版本比对 → 灰度命中 → 更新内存
- **兜底**:app **内置** `me.json`(bundle 资源),拉取失败 / 首次 / 无网 → 用内置,保证永远可用
- **回滚**:新版渲染失败 → 回退上一个本地版本(复用游戏 fallback 思路)
- OSS:`oss://cz-rn-bundle/pages/manifest.json` + `pages/me/me-v1.0.json`

### 3.8 路由接入

- 注册 `wechat://page/{id}` → `DSLPageViewController(pageId: id)`
- MeModule:`MainTabBarController` 的「我的」Tab 换成 `DSLPageViewController(pageId: "me")`(或 MeViewController 内部改用 DSLRenderer,保留 Tab 结构)

---

## 4. 生产级要点(面试必答,必须有)

1. **兜底**:拉取失败 → 内置 schema,永远可渲染
2. **向前兼容**:未知 `type` / 未知字段 → 跳过 / 忽略,**老客户端不崩**(新组件灰度上线的前提)
3. **能力协商**:`minClient` < 客户端能力版本才渲染,否则用兜底
4. **完整性**:sha256 校验 + 失败回滚(复用游戏那套)
5. **灰度**:复用 `grayscaleHit`(deviceId hash + 白名单 + 百分比)

---

## 5. 和 RN/H5 的边界(动态化分层叙事)

```
原生        → 核心、重交互、极致性能(IM、Tab 容器)
DSL/SDUI    → 轻量列表/卡片/运营页,要秒开 + 包小 + 原生质感   ← 本项目新增
RN / H5     → 重动态业务、复杂逻辑(朋友圈、游戏)
```
DSL 填「比原生灵活、比 RN/H5 轻」的中间地带。

---

## 6. AI 的角色

1. **批量生成 schema**:运营页 / 活动页几十个,AI 几分钟出
2. **生成组件 builder 脚手架**
3. **杀手锏 demo(Phase 4)**:**自然语言 → DSL**(「做个三栏图标 + 顶部 banner 的活动页」→ AI 吐 JSON → app 实时渲染)

---

## 7. 分阶段

- **Phase 1(本设计)**:DSLKit 引擎(模型 + 注册表 + 渲染器 + 动作)+ `profileHeader`/`group`/`cell` 组件 + `PageSchemaManager`(内置兜底 + OSS 下发)+ 「我的」整页 DSL 化 + 路由接入
- **Phase 2**:楼层型(UICollectionView CompositionalLayout)+ 活动页 + 数据绑定 `{{ }}`
- **Phase 3**:IM 结构化消息卡片(订单卡/链接卡/小程序卡,和 IM 2.0 结合)
- **Phase 4**:自然语言 → schema / A/B / 埋点闭环

---

## 8. 验收(Phase 1 Done 标准)

1. 「我的」页**完全由 me.json 渲染**(头部 + 三个分组),视觉与现状一致
2. 改 OSS 上的 `me.json`(如新增一个 cell / 改标题 / 调顺序)→ 杀 app 重启 → 页面变化,**零发版**
3. OSS 不可达 / sha256 不符 → 自动用内置兜底,页面正常
4. me.json 里塞一个**未知 type** 组件 → 该项被跳过,页面不崩
5. 点击「设置」等 cell → 正常路由
6. 单测:DSLPage 解析、未知 type 容错、PageSchemaManager 版本/灰度/回退
```
