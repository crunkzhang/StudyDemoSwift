# WeChatSwift 静态库 + podspec 模块化迁移设计

## 背景

当前项目使用 `use_frameworks! :linkage => :dynamic` + 嵌套 target 管理 CocoaPods 依赖。希望切换为静态库以获得更快的启动速度和更小的包体。但静态库模式下，多个 target 各自声明同一 pod 会导致重复链接。

参考 SoulApp 的 Podfile 架构（单 target 扁平模式 + podspec 管理模块依赖），对本项目进行全面迁移。

## 目标

1. 切换为 `use_frameworks! :linkage => :static`，消除动态库加载开销
2. 将 11 个 Xcode framework target 转为 CocoaPods 本地 pod（各自有 `.podspec`）
3. Podfile 合并为单 app target 扁平声明
4. `project.yml` 精简为只保留 app target
5. 业务源码零改动

## 不在本次范围

- RN pods 二进制化（`use_react_native!()` 展开的几十个 RN 子 pod 保持平铺）
- SnapKit 使用收敛（业务模块继续直接 `import SnapKit`）

## 架构变化

### 当前

```
Podfile:       WeChatUI target 持有 SnapKit，WeChatRN target 持有 RN pods
project.yml:   11 个 framework target + 1 个 app target，依赖关系在 dependencies 里
linkage:       dynamic
```

### 迁移后

```
Podfile:       WeChatSwift (app) 单 target 持有全部 pod
project.yml:   只保留 1 个 app target
podspec:       11 个本地 pod 各自声明依赖关系
linkage:       static
```

### Xcode 导航栏变化

模块源码从主项目 xcodeproj 的 framework target 移到 Pods 项目的 Development Pods 下。文件物理路径不变（`:path =>` 直接引用原目录）。

使用 `generate_multiple_pod_projects: true`，每个 pod 生成独立 xcodeproj。

## 模块依赖关系

依赖方向严格单向向下：

```
Business 层:
  ChatModule     → WeChatUI, WeChatRouter, WeChatRN, ExtensionKit, SnapKit
  ContactModule  → WeChatUI, WeChatRouter, ExtensionKit, SnapKit
  DiscoverModule → WeChatUI, WeChatRouter, WeChatRN, ExtensionKit, SnapKit
  MeModule       → WeChatUI, WeChatRouter, WeChatNetAPI, ExtensionKit, SnapKit

Platform 层:
  WeChatUI       → ExtensionKit, SnapKit
  WeChatRouter   → NavigateKit
  WeChatNetAPI   → DDNetwork
  WeChatRN       → WeChatNetAPI, WeChatUI, WeChatRouter, NavigateKit

Foundation 层:
  ExtensionKit   → (无)
  NavigateKit    → (无)
  DDNetwork      → (无)
```

## podspec 规划

共 11 个 podspec，其中 2 个已有需更新，9 个新增。

| 模块 | 位置 | source_files | dependency | 状态 |
|---|---|---|---|---|
| ExtensionKit | `Foundation/ExtensionKit/` | `UIKit/**/*.swift` | 无 | 更新 |
| NavigateKit | `Foundation/NavigateKit/` | `Core/**/*.swift` | 无 | 更新 |
| DDNetwork | `Foundation/DDNetwork/` | `Core/**/*.swift`, `Models/**/*.swift`, `Interceptors/**/*.swift`, `Build/**/*.swift` | 无 | 新增 |
| WeChatUI | `Modules/WeChatKit/WeChatUI/` | `Base/**/*.swift`, `Components/**/*.swift`, `Theme/**/*.swift`, `WeChatUI.swift` | ExtensionKit, SnapKit | 新增 |
| WeChatRouter | `Modules/WeChatKit/WeChatRouter/` | `*.swift` | NavigateKit | 新增 |
| WeChatNetAPI | `Modules/WeChatKit/WeChatNetAPI/` | `*.swift` | DDNetwork | 新增 |
| WeChatRN | `Modules/WeChatKit/WeChatRN/` | `**/*.swift` | WeChatNetAPI, WeChatUI, WeChatRouter, NavigateKit | 新增 |
| ChatModule | `Modules/Business/ChatModule/` | `**/*.swift` | WeChatUI, WeChatRouter, WeChatRN, ExtensionKit, SnapKit | 新增 |
| ContactModule | `Modules/Business/ContactModule/` | `**/*.swift` | WeChatUI, WeChatRouter, ExtensionKit, SnapKit | 新增 |
| DiscoverModule | `Modules/Business/DiscoverModule/` | `**/*.swift` | WeChatUI, WeChatRouter, WeChatRN, ExtensionKit, SnapKit | 新增 |
| MeModule | `Modules/Business/MeModule/` | `**/*.swift` | WeChatUI, WeChatRouter, WeChatNetAPI, ExtensionKit, SnapKit | 新增 |

WeChatRN 的 podspec 不声明 React-Native 相关 dependency。RN pods 由 Podfile 中 `use_react_native!()` 统一管理。

## Podfile 设计

```ruby
rn_project = File.expand_path('../WeChatRN', __dir__)
rn_path    = '../WeChatRN/node_modules/react-native'

require Pod::Executable.execute_command('node', ['-p',
  'require.resolve(
    "react-native/scripts/react_native_pods.rb",
    {paths: [process.argv[1]]},
  )', rn_project]).strip

platform :ios, '15.1'
prepare_react_native_project!
use_frameworks! :linkage => :static

install! 'cocoapods',
  :deterministic_uuids => false,
  :generate_multiple_pod_projects => true

target 'WeChatSwift' do
  # Foundation 层
  pod 'ExtensionKit',   :path => 'Foundation/ExtensionKit'
  pod 'NavigateKit',    :path => 'Foundation/NavigateKit'
  pod 'DDNetwork',      :path => 'Foundation/DDNetwork'

  # Platform 层
  pod 'WeChatUI',       :path => 'Modules/WeChatKit/WeChatUI'
  pod 'WeChatRouter',   :path => 'Modules/WeChatKit/WeChatRouter'
  pod 'WeChatNetAPI',   :path => 'Modules/WeChatKit/WeChatNetAPI'
  pod 'WeChatRN',       :path => 'Modules/WeChatKit/WeChatRN'

  # Business 层
  pod 'ChatModule',     :path => 'Modules/Business/ChatModule'
  pod 'ContactModule',  :path => 'Modules/Business/ContactModule'
  pod 'DiscoverModule', :path => 'Modules/Business/DiscoverModule'
  pod 'MeModule',       :path => 'Modules/Business/MeModule'

  # 三方库
  pod 'SnapKit'

  # RN
  use_react_native!(:path => rn_path, :app_path => rn_project)
  pod 'react-native-safe-area-context', :path => '../WeChatRN/node_modules/react-native-safe-area-context'
  pod 'RNScreens', :path => '../WeChatRN/node_modules/react-native-screens'
  pod 'react-native-webview', :path => '../WeChatRN/node_modules/react-native-webview'
  pod 'RNSVG', :path => '../WeChatRN/node_modules/react-native-svg'
end

post_install do |installer|
  react_native_post_install(
    installer,
    rn_path,
    :mac_catalyst_enabled => false,
  )
end
```

## project.yml 设计

精简为只保留 app target：

```yaml
name: WeChatSwift
options:
  bundleIdPrefix: com.study
  deploymentTarget:
    iOS: "15.1"
  developmentLanguage: zh-Hans

targets:
  WeChatSwift:
    type: application
    platform: iOS
    sources:
      - WeChatSwift
    info:
      path: WeChatSwift/Info.plist
      properties:
        # 保持现有配置不变
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.study.wcSwift
      SWIFT_VERSION: "5.0"
      TARGETED_DEVICE_FAMILY: "1"
      INFOPLIST_FILE: WeChatSwift/Info.plist
      CODE_SIGN_STYLE: Automatic
      DEVELOPMENT_TEAM: 2DAFKPU228

schemes:
  WeChatSwift:
    build:
      targets:
        WeChatSwift: all
    run:
      config: Debug
    archive:
      config: Release
```

## 开发流程变化

迁移后本地开发和 CI 统一执行：

```bash
#!/bin/bash
# setup.sh
xcodegen generate && pod install
```

## 风险与应对

### 风险 1：WeChatRN 编译找不到 RN 头文件

WeChatRN 的 podspec 没声明对 React-Core 等的 dependency，但源码 import 了 RN 的类。

应对：先尝试依赖同 target 下的 header search path 自动发现。如果编译失败，在 WeChatRN.podspec 中按编译报错逐个补充 `s.dependency 'React-Core'` 等声明。

### 风险 2：静态库 + use_react_native! 兼容性

RN 官方 `use_react_native!` 宏默认假设动态框架，切 static 后 Hermes 等可能有链接问题。

应对：RN 0.72+ 对静态库支持较好，需实测验证。兜底方案：对 hermes-engine 单独保持动态 `pod 'hermes-engine', :linkage => :dynamic`。

### 风险 3：xcodegen 生成时机

project.yml 改后只剩 app target，framework target 全由 CocoaPods 生成。必须按 `xcodegen generate → pod install` 顺序执行。

应对：提供 `setup.sh` 脚本固化流程。

### 风险 4：podspec 的 source_files 路径

podspec 的 source_files 相对于 podspec 文件所在目录。需确保路径精确匹配实际目录结构。

应对：写完 podspec 后逐个 `pod lib lint` 验证。

## 改动清单

| 操作 | 数量 |
|---|---|
| 新增 podspec | 9 个 |
| 更新已有 podspec | 2 个 |
| 重写 Podfile | 1 个 |
| 精简 project.yml | 1 个 |
| 删除空目录 | 3 个（WeChatModels, WeChatService, WeChatRNKit） |
| 新增 setup.sh | 1 个 |
| 业务源码改动 | 0 个 |

## 预期收益

| 指标 | 变化 |
|---|---|
| 冷启动时间 | 减少约 30-60ms（消除 ~20 个 dylib 加载） |
| 包体大小 | 持平或略小（dead code stripping） |
| Pod 管理复杂度 | 降低（加库只改 Podfile 一处） |
| 依赖关系来源 | 统一到 podspec（消除 project.yml + Podfile 两处维护） |
