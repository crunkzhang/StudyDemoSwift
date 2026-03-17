# WeChatSwift 架构设计文档

## 项目概览

- **项目类型**: iOS 原生应用
- **开发语言**: Swift
- **最低支持版本**: iOS 15.1+
- **构建系统**: XcodeGen (project.yml)
- **依赖管理**: CocoaPods
- **架构模式**: 模块化分层架构

## 架构分层

WeChatSwift 采用清晰的四层架构设计，从底层到上层依次为：

### 第一层：Foundation（通用基础组件）

**位置**: `Modules/Foundation/`

这一层包含可跨项目复用的通用框架，不依赖任何业务逻辑。

#### 已实现的框架

1. **RouterKit** - URL 路由系统
   - 文件: `RouterKit/Core/Router.swift`
   - 核心类: `Router` (单例)
   - 协议: `Routable`
   - 功能:
     - URL 模式匹配 (如 `wechat://chat/detail`)
     - 参数解析 (query parameters)
     - ViewController 解析和导航
     - 支持 push 和 present 两种导航方式
   - 使用方: 所有业务模块

2. **ExtensionKit** - UIKit 扩展
   - 文件: `ExtensionKit/UIKit/UIColor+Hex.swift`
   - 功能: 支持十六进制颜色字符串初始化 UIColor
   - 示例: `UIColor(hex: "#07C160")`

#### 规划中的框架

- **LogKit**: 日志系统
- **MediaKit**: 图片/视频处理
- **NetworkKit**: 网络请求封装
- **StorageKit**: 数据持久化
- **UtilKit**: 通用工具函数

**设计原则**:
- 零业务依赖
- 高度可复用
- 单一职责

---

### 第二层：WeChatKit（微信特定组件）

**位置**: `Modules/WeChatKit/`

这一层包含微信项目特有的共享组件，可在微信的各个业务模块间复用。

#### 已实现的框架

1. **WeChatUI** - UI 主题和组件
   - 文件: `WeChatUI/Theme/WeChatTheme.swift`
   - 提供:
     - 主题色定义 (微信绿 #07C160)
     - 背景色、分割线色、文本色
     - 图标色系统
   - 依赖: ExtensionKit, SnapKit

2. **WeChatRouter** - 路由定义
   - 文件: `WeChatRouter/Routes.swift`
   - 定义所有功能的路由常量:
     - 发现页: `moments`, `videoChannel`, `scan`, `shake`, `nearby`, `shopping`, `game`, `search`
     - 聊天: `chatDetail`
   - 依赖: RouterKit

3. **WeChatBridge** - React Native 桥接
   - 文件: `WeChatBridge/RNFactoryManager.swift`
   - 核心类: `RNFactoryManager` (单例)
   - 协议: `ReactNativeFactoryProvider`
   - 功能: 让原生 Swift 代码能够渲染 React Native 组件
   - 依赖: React, React_RCTAppDelegate

#### 规划中的框架

- **WeChatModels**: 共享数据模型
- **WeChatService**: 业务逻辑服务

**设计原则**:
- 微信项目特定
- 跨业务模块共享
- 依赖 Foundation 层

---

### 第三层：Business Modules（业务模块）

**位置**: `Modules/Modules/`

每个业务模块都是独立的 framework，包含完整的 UI、路由、数据模型。

#### ChatModule（聊天模块）

**主要文件**:
- `Chat/ChatViewController.swift` - 会话列表
- `ChatDetail/RNChatDetailViewController.swift` - 聊天详情（React Native）
- `Models/ChatConversation.swift` - 会话数据模型
- `Chat/ChatListCell.swift` - 会话列表 Cell
- `ChatRoutes.swift` - 路由注册

**功能**:
- 显示 100 条模拟会话
- 每个会话包含: 头像、昵称、最后消息、时间、未读数
- 点击会话跳转到 React Native 实现的聊天详情页

**依赖**: WeChatUI, WeChatRouter, WeChatBridge, RouterKit, ExtensionKit, React, SnapKit

---

#### ContactModule（通讯录模块）

**主要文件**:
- `ContactList/ContactsViewController.swift` - 联系人列表
- `ContactList/ContactCell.swift` - 联系人 Cell
- `Models/MockContactData.swift` - 模拟数据
- `ContactRoutes.swift` - 路由入口

**功能**:
- 顶部操作项（新朋友、群聊、标签、公众号）
- 按拼音首字母分组的联系人列表（50+ 联系人）
- 右侧字母索引

**依赖**: WeChatUI, WeChatRouter, RouterKit, ExtensionKit, SnapKit

---

#### DiscoverModule（发现模块）

**主要文件**:
- `Discover/DiscoverViewController.swift` - 发现页主界面
- 8 个子功能页面:
  - `Moments/MomentsViewController.swift` - 朋友圈
  - `VideoChannel/VideoChannelViewController.swift` - 视频号
  - `Scan/ScanViewController.swift` - 扫一扫
  - `Shake/ShakeViewController.swift` - 摇一摇
  - `Nearby/NearbyViewController.swift` - 附近的人
  - `Shopping/ShoppingViewController.swift` - 购物
  - `Game/GameViewController.swift` - 游戏
  - `Search/SearchViewController.swift` - 搜一搜
- `DiscoverRoutes.swift` - 注册所有 8 个路由

**功能**:
- 分组展示 8 个发现功能
- 每个功能有图标、颜色、标题
- 点击跳转到对应子页面（当前为占位页面）

**依赖**: WeChatUI, WeChatRouter, RouterKit, ExtensionKit, SnapKit

---

#### MeModule（我的模块）

**主要文件**:
- `Profile/MeViewController.swift` - 个人中心
- `MeRoutes.swift` - 路由入口

**功能**:
- 个人信息头部（头像、昵称、微信号、二维码）
- 三组菜单项:
  - 服务（支付、收藏、卡包等）
  - 内容（朋友圈、视频号、收藏、表情）
  - 设置（设置）

**依赖**: WeChatUI, WeChatRouter, RouterKit, ExtensionKit, SnapKit

---

### 第四层：Main Application（主应用）

**位置**: `WeChatSwift/`

应用的入口和主框架。

#### 核心文件

1. **AppDelegate.swift**
   - 初始化 React Native factory 和 delegate
   - 在启动时注册所有模块的路由
   - 配置 React Native bundle URL（debug/release）

2. **SceneDelegate.swift**
   - 创建 window
   - 设置 `MainTabBarController` 为根视图控制器

3. **MainTabBarController.swift**
   - 四个 Tab:
     - 微信 (ChatViewController)
     - 通讯录 (ContactsViewController)
     - 发现 (DiscoverViewController)
     - 我 (MeViewController)
   - 每个 Tab 包裹在 UINavigationController 中
   - 使用微信绿主题色 (#07C160)

**依赖**: 所有业务模块 + WeChatKit 层

---

## 依赖关系图

```
┌─────────────────────────────────────────────────────────────┐
│                    WeChatSwift (App)                        │
│         AppDelegate + SceneDelegate + TabBar                │
└────────────────────────────────────────────────────────────┬┘
                                                              │
                    ┌─────────────────────────────────────────┼─────────────────────┐
                    │                                         │                     │
        ┌───────────▼──────────┐  ┌──────────────────┐  ┌───▼─────────────┐  ┌───▼──────────────┐
        │   ChatModule         │  │ ContactModule    │  │ DiscoverModule  │  │   MeModule       │
        │ (RN Chat Detail)     │  │                  │  │                 │  │                  │
        └───────────┬──────────┘  └────┬─────────────┘  └────────┬────────┘  └────────┬─────────┘
                    │                  │                          │                    │
                    └──────────────────┼──────────────────────────┼────────────────────┘
                                       │                          │
                    ┌──────────────────┴──────────────────────────┴────────────────────┐
                    │                                                                   │
        ┌───────────▼──────────┐  ┌──────────────────┐  ┌──────────────────┐  ┌──────▼────────┐
        │   WeChatUI           │  │  WeChatRouter    │  │  WeChatBridge    │  │ WeChatModels  │
        │ (Theme, Components)  │  │  (Route Defs)    │  │  (RN Factory)    │  │ (Placeholder) │
        └───────────┬──────────┘  └────────┬─────────┘  └────────┬─────────┘  └───────────────┘
                    │                      │                      │
                    └──────────────────────┼──────────────────────┘
                                           │
        ┌──────────────────────────────────┼──────────────────────────────────┐
        │                                  │                                  │
    ┌───▼──────────┐  ┌──────────────┐  ┌─▼──────────┐  ┌────────────────┐  │
    │ RouterKit    │  │ ExtensionKit │  │ React      │  │ SnapKit        │  │
    │ (URL Router) │  │ (UIKit Ext)  │  │ (RN Core)  │  │ (Auto Layout)  │  │
    └──────────────┘  └──────────────┘  └────────────┘  └────────────────┘  │
                                                                              │
    ┌──────────────────────────────────────────────────────────────────────┐ │
    │ Foundation Layer (Placeholder)                                       │ │
    │ LogKit, MediaKit, NetworkKit, StorageKit, UtilKit                    │ │
    └──────────────────────────────────────────────────────────────────────┘ │
                                                                              │
    └──────────────────────────────────────────────────────────────────────────┘
```

## 设计模式

### 1. 模块化架构
- 每个功能（聊天、通讯录、发现、我）都是独立的 framework
- 模块间通过协议和路由通信，避免直接依赖
- 便于并行开发和单元测试

### 2. URL 路由
- 所有页面跳转通过 URL 模式实现
- 示例: `Router.shared.push("wechat://chat/detail?chatId=123&contactName=张三")`
- 解耦页面间的直接依赖

### 3. 协议驱动
- `Routable` 协议: 模块路由注册
- `ReactNativeFactoryProvider` 协议: RN 工厂提供者
- 面向接口编程，提高可测试性

### 4. 单例模式
- `Router.shared`: 全局路由器
- `RNFactoryManager.shared`: RN 工厂管理器
- 确保全局唯一实例

### 5. Mock 数据
- 所有模块使用 Mock 数据进行开发
- 便于 UI 开发和调试
- 后续可替换为真实 API

### 6. React Native 混合开发
- ChatModule 的详情页使用 React Native 实现
- 通过 `WeChatBridge` 桥接原生和 RN
- 展示了混合开发的可行性

## 外部依赖

### CocoaPods 依赖

- **SnapKit**: 声明式 Auto Layout DSL
- **React Native**: 核心框架 + RCTAppDelegate
- **react-native-safe-area-context**: 安全区域处理

## 当前实现状态

### ✅ 已完成

- 四 Tab 主界面（微信、通讯录、发现、我）
- 聊天列表（100 条模拟会话）
- 通讯录列表（50+ 联系人，按拼音分组）
- 发现页（8 个功能入口）
- 个人中心（头像、菜单）
- URL 路由系统
- React Native 集成（聊天详情页）
- 主题色系统

### ⏳ 待完成

- Foundation 层框架（LogKit, MediaKit, NetworkKit, StorageKit, UtilKit）
- WeChatKit 层框架（WeChatModels, WeChatService）
- ContactModule 和 MeModule 的路由注册
- 发现页 8 个子功能的具体实现（当前为占位页面）
- 真实数据接口对接
- 用户认证和登录
- 消息推送
- 数据持久化

## 架构优势

### 1. 清晰的分层
- 每一层职责明确
- 依赖关系单向（上层依赖下层）
- 易于理解和维护

### 2. 高度模块化
- 业务模块独立
- 可独立编译和测试
- 支持团队并行开发

### 3. 可扩展性强
- 新增功能只需添加新模块
- 不影响现有模块
- Foundation 层可持续扩充

### 4. 技术栈灵活
- 支持纯原生开发
- 支持 React Native 混合开发
- 可根据场景选择最优方案

### 5. 易于测试
- 模块间解耦
- 协议驱动设计
- Mock 数据支持

## 架构改进建议

### 1. 消除重复代码
- 主应用中的 `Router.swift` 与 `RouterKit` 功能重复
- 主应用中的 Models 和 Views 与模块中的重复
- 建议: 统一使用模块中的实现

### 2. 完善 Foundation 层
- 实现 LogKit（统一日志）
- 实现 NetworkKit（网络请求）
- 实现 StorageKit（数据持久化）

### 3. 抽象共享服务
- 实现 WeChatService（用户、消息、联系人服务）
- 实现 WeChatModels（共享数据模型）

### 4. 路由注册优化
- ContactModule 和 MeModule 尚未注册路由
- 建议: 补充路由注册，实现页面跳转

### 5. 依赖注入
- 当前使用单例模式
- 建议: 引入依赖注入容器，提高可测试性

## 构建和运行

### 前置条件
- Xcode 17+
- CocoaPods
- XcodeGen
- Node.js（用于 React Native）

### 构建步骤

```bash
cd WeChatSwift

# 1. 生成 Xcode 项目（如果修改了 project.yml）
xcodegen generate

# 2. 安装 CocoaPods 依赖
pod install

# 3. 打开工作空间（必须用 .xcworkspace）
open WeChatSwift.xcworkspace

# 4. 或直接编译运行
xcodebuild build -workspace WeChatSwift.xcworkspace \
  -scheme WeChatSwift \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

### 注意事项
- 必须使用 `.xcworkspace` 而非 `.xcodeproj`（CocoaPods 依赖）
- 修改 `project.yml` 后需重新运行 `xcodegen generate` 和 `pod install`
- 基础 framework 需在主工程 target 中显式 `embed: true`

## 总结

WeChatSwift 采用了清晰的四层架构设计，从底层的通用组件到上层的业务模块，层次分明、职责清晰。模块化的设计使得项目易于扩展和维护，URL 路由系统实现了模块间的解耦，React Native 的集成展示了混合开发的灵活性。

当前项目已完成主要框架和 UI 实现，后续需要补充网络、存储等基础设施，并对接真实数据接口，最终实现一个功能完整的微信客户端。
