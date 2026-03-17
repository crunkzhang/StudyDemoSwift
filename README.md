# WeChatSwift

仿微信 iOS 原生项目，使用 Swift + UIKit 开发。

## 技术栈

- **语言**: Swift 5.0
- **UI 框架**: UIKit
- **架构**: 模块化 + 路由
- **依赖管理**: CocoaPods
- **项目生成**: XcodeGen

## 项目结构

```
WeChatSwift/
├── Modules/
│   ├── Foundation/          # 通用基础组件层（可跨项目复用）
│   │   ├── RouterKit/       # 路由框架
│   │   └── ExtensionKit/    # 扩展工具
│   ├── WeChatKit/           # 项目基础组件层（微信特有）
│   │   ├── WeChatUI/        # UI 组件库
│   │   ├── WeChatRouter/    # 路由配置
│   │   └── WeChatBridge/    # RN 桥接
│   └── Modules/             # 业务模块层
│       ├── ChatModule/      # 聊天模块
│       ├── ContactModule/   # 通讯录模块
│       ├── DiscoverModule/  # 发现模块
│       └── MeModule/        # 我的模块
├── WeChatSwift/             # 主工程
├── project.yml              # XcodeGen 配置
└── Podfile                  # CocoaPods 配置
```

## 快速开始

### 环境要求

- Xcode 15.0+
- iOS 15.1+
- CocoaPods
- XcodeGen
- Node.js（用于 React Native 集成）

### 安装依赖

```bash
# 1. 安装 XcodeGen（如果还没安装）
brew install xcodegen

# 2. 生成 Xcode 项目
xcodegen generate

# 3. 安装 CocoaPods 依赖
pod install

# 4. 打开项目（必须使用 .xcworkspace）
open WeChatSwift.xcworkspace
```

### 运行项目

**方式 1: 使用 Xcode**
```bash
open WeChatSwift.xcworkspace
# 在 Xcode 中选择模拟器并运行
```

**方式 2: 使用命令行**
```bash
xcodebuild build -workspace WeChatSwift.xcworkspace \
  -scheme WeChatSwift \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

## 开发说明

### 修改项目配置

1. 修改 `project.yml` 文件
2. 运行 `xcodegen generate` 重新生成项目
3. 如果修改了依赖，运行 `pod install`

### 添加新模块

1. 在 `Modules/` 对应目录下创建模块文件夹
2. 在 `project.yml` 中添加 target 配置
3. 在 `Podfile` 中添加对应的 target（如果需要依赖）
4. 运行 `xcodegen generate && pod install`

### React Native 集成

本项目集成了 React Native，可以在原生页面中嵌入 RN 页面：

- RN 项目位置: `../WeChatRN`
- 桥接模块: `WeChatBridge`
- 使用模块: `ChatModule`（示例）

## 注意事项

⚠️ **重要提醒**

1. **必须使用 `.xcworkspace` 打开项目**，不要使用 `.xcodeproj`
2. **不要手动修改 `.xcodeproj` 和 `.xcworkspace` 文件**，它们由 XcodeGen 自动生成
3. **不要提交 `Pods/` 目录**，团队成员需要自行运行 `pod install`
4. **不要提交 `Podfile.lock`**，避免依赖版本冲突
5. 修改 `project.yml` 后必须重新运行 `xcodegen generate`

## 团队协作

### 克隆项目后的设置

```bash
# 1. 克隆仓库
git clone <repository-url>
cd WeChatSwift

# 2. 生成项目文件
xcodegen generate

# 3. 安装依赖
pod install

# 4. 打开项目
open WeChatSwift.xcworkspace
```

## 架构说明

### 三层架构

1. **Foundation 层**: 通用基础组件，可跨项目复用
2. **WeChatKit 层**: 微信特有的基础组件
3. **Modules 层**: 具体业务模块

### 模块依赖关系

```
WeChatSwift (主工程)
  ├── ChatModule
  ├── ContactModule
  ├── DiscoverModule
  └── MeModule
      └── WeChatUI
      └── WeChatRouter
      └── WeChatBridge (仅 ChatModule)
          └── RouterKit
          └── ExtensionKit
```

## 许可证

学习项目，仅供参考。
