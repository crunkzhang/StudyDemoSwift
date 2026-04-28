# 静态库 + podspec 模块化迁移 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 WeChatSwift 从动态库 + 嵌套 target 切换为静���库 + podspec 单 target 扁平模式，参考 SoulApp 架构。

**Architecture:** 11 个 Xcode framework target 转为 CocoaPods 本地 pod（各有 `.podspec`），Podfile 合并为单 app target，`project.yml` 精简为只保留 app target。模块间依赖关系由 podspec 的 `dependency` 管理。

**Tech Stack:** CocoaPods, XcodeGen (project.yml), React Native, Swift 5.0, iOS 15.1+

---

## File Map

### 新增文件（9 个 podspec）
- `Foundation/DDNetwork/DDNetwork.podspec`
- `Modules/WeChatKit/WeChatUI/WeChatUI.podspec`
- `Modules/WeChatKit/WeChatRouter/WeChatRouter.podspec`
- `Modules/WeChatKit/WeChatNetAPI/WeChatNetAPI.podspec`
- `Modules/WeChatKit/WeChatRN/WeChatRN.podspec`
- `Modules/Business/ChatModule/ChatModule.podspec`
- `Modules/Business/ContactModule/ContactModule.podspec`
- `Modules/Business/DiscoverModule/DiscoverModule.podspec`
- `Modules/Business/MeModule/MeModule.podspec`
- `setup.sh`

### 修改文件（4 个）
- `Foundation/ExtensionKit/ExtensionKit.podspec` — 更新 source_files 路径
- `Foundation/NavigateKit/NavigateKit.podspec` — 更新 source_files 路径
- `Podfile` — 重写为单 target 扁平模式
- `project.yml` — 精简为只保留 app target

### 删除目录（3 个）
- `Modules/WeChatKit/WeChatModels/`
- `Modules/WeChatKit/WeChatService/`
- `Modules/WeChatKit/WeChatRNKit/`

---

## Task 1: 删除空目录 + 创建 setup.sh

**Files:**
- Delete: `Modules/WeChatKit/WeChatModels/`
- Delete: `Modules/WeChatKit/WeChatService/`
- Delete: `Modules/WeChatKit/WeChatRNKit/`
- Create: `setup.sh`

- [ ] **Step 1: 删除三个空目录**

```bash
rm -rf Modules/WeChatKit/WeChatModels Modules/WeChatKit/WeChatService Modules/WeChatKit/WeChatRNKit
```

- [ ] **Step 2: 创建 setup.sh**

```bash
#!/bin/bash
set -euo pipefail

echo "==> Generating Xcode project..."
xcodegen generate

echo "==> Installing pods..."
pod install

echo "==> Done! Open WeChatSwift.xcworkspace"
```

- [ ] **Step 3: 设置执行权限**

```bash
chmod +x setup.sh
```

- [ ] **Step 4: Commit**

```bash
git add -A Modules/WeChatKit/WeChatModels Modules/WeChatKit/WeChatService Modules/WeChatKit/WeChatRNKit setup.sh
git commit -m "chore: 删除空目录，添加 setup.sh"
```

---

## Task 2: Foundation 层 podspec（ExtensionKit, NavigateKit, DDNetwork）

**Files:**
- Modify: `Foundation/ExtensionKit/ExtensionKit.podspec`
- Modify: `Foundation/NavigateKit/NavigateKit.podspec`
- Create: `Foundation/DDNetwork/DDNetwork.podspec`

- [ ] **Step 1: 更新 ExtensionKit.podspec**

将 `source_files` 从 `**/*.swift`（会匹配到 podspec 同级所有 swift）改为精确路径：

```ruby
Pod::Spec.new do |s|
  s.name             = 'ExtensionKit'
  s.version          = '1.0.0'
  s.summary          = 'Swift 扩展工具库'
  s.description      = 'UIKit 和 Foundation 的常用扩展，可跨项目复用。'
  s.homepage         = 'https://github.com/nicedayzhu/WeChatSwift'
  s.license          = { :type => 'MIT' }
  s.author           = { 'nicedayzhu' => 'nicedayzhu@example.com' }
  s.source           = { :git => '', :tag => s.version.to_s }

  s.ios.deployment_target = '15.1'
  s.swift_version = '5.0'

  s.source_files = 'UIKit/**/*.swift'

  s.frameworks = 'UIKit', 'Foundation'
end
```

- [ ] **Step 2: 更新 NavigateKit.podspec**

```ruby
Pod::Spec.new do |s|
  s.name             = 'NavigateKit'
  s.version          = '1.0.0'
  s.summary          = 'Swift 页��跳转工具'
  s.description      = '提供纯页面跳转能力，不包含路由注册逻辑���'
  s.homepage         = 'https://github.com/nicedayzhu/WeChatSwift'
  s.license          = { :type => 'MIT' }
  s.author           = { 'nicedayzhu' => 'nicedayzhu@example.com' }
  s.source           = { :git => '', :tag => s.version.to_s }

  s.ios.deployment_target = '15.1'
  s.swift_version = '5.0'

  s.source_files = 'Core/**/*.swift'

  s.frameworks = 'UIKit', 'Foundation'
end
```

- [ ] **Step 3: 新增 DDNetwork.podspec**

```ruby
Pod::Spec.new do |s|
  s.name             = 'DDNetwork'
  s.version          = '1.0.0'
  s.summary          = '网络请求基础库'
  s.description      = '通用网络层，提供 API 请求、拦截器、响应解码等能力。'
  s.homepage         = 'https://github.com/nicedayzhu/WeChatSwift'
  s.license          = { :type => 'MIT' }
  s.author           = { 'nicedayzhu' => 'nicedayzhu@example.com' }
  s.source           = { :git => '', :tag => s.version.to_s }

  s.ios.deployment_target = '15.1'
  s.swift_version = '5.0'

  s.source_files = 'Core/**/*.swift', 'Models/**/*.swift', 'Interceptors/**/*.swift', 'Build/**/*.swift'

  s.frameworks = 'Foundation'
end
```

- [ ] **Step 4: Commit**

```bash
git add Foundation/ExtensionKit/ExtensionKit.podspec Foundation/NavigateKit/NavigateKit.podspec Foundation/DDNetwork/DDNetwork.podspec
git commit -m "feat: Foundation 层 podspec（ExtensionKit, NavigateKit, DDNetwork）"
```

---

## Task 3: Platform 层 podspec（WeChatUI, WeChatRouter, WeChatNetAPI, WeChatRN）

**Files:**
- Create: `Modules/WeChatKit/WeChatUI/WeChatUI.podspec`
- Create: `Modules/WeChatKit/WeChatRouter/WeChatRouter.podspec`
- Create: `Modules/WeChatKit/WeChatNetAPI/WeChatNetAPI.podspec`
- Create: `Modules/WeChatKit/WeChatRN/WeChatRN.podspec`

- [ ] **Step 1: 新增 WeChatUI.podspec**

```ruby
Pod::Spec.new do |s|
  s.name             = 'WeChatUI'
  s.version          = '1.0.0'
  s.summary          = '微信 UI 基础组件库'
  s.description      = '主题、基础 ViewController、通用 UI 组件。'
  s.homepage         = 'https://github.com/nicedayzhu/WeChatSwift'
  s.license          = { :type => 'MIT' }
  s.author           = { 'nicedayzhu' => 'nicedayzhu@example.com' }
  s.source           = { :git => '', :tag => s.version.to_s }

  s.ios.deployment_target = '15.1'
  s.swift_version = '5.0'

  s.source_files = 'Base/**/*.swift', 'Theme/**/*.swift', 'WeChatUI.swift'

  s.frameworks = 'UIKit', 'Foundation'

  s.dependency 'ExtensionKit'
  s.dependency 'SnapKit'
end
```

- [ ] **Step 2: 新增 WeChatRouter.podspec**

```ruby
Pod::Spec.new do |s|
  s.name             = 'WeChatRouter'
  s.version          = '1.0.0'
  s.summary          = '微信路由管理'
  s.description      = '页面路由注册与跳转管理。'
  s.homepage         = 'https://github.com/nicedayzhu/WeChatSwift'
  s.license          = { :type => 'MIT' }
  s.author           = { 'nicedayzhu' => 'nicedayzhu@example.com' }
  s.source           = { :git => '', :tag => s.version.to_s }

  s.ios.deployment_target = '15.1'
  s.swift_version = '5.0'

  s.source_files = '*.swift'

  s.frameworks = 'UIKit', 'Foundation'

  s.dependency 'NavigateKit'
end
```

- [ ] **Step 3: 新增 WeChatNetAPI.podspec**

```ruby
Pod::Spec.new do |s|
  s.name             = 'WeChatNetAPI'
  s.version          = '1.0.0'
  s.summary          = '微信网络 API 层'
  s.description      = '基于 DDNetwork 封装的微信业务 API 客户端。'
  s.homepage         = 'https://github.com/nicedayzhu/WeChatSwift'
  s.license          = { :type => 'MIT' }
  s.author           = { 'nicedayzhu' => 'nicedayzhu@example.com' }
  s.source           = { :git => '', :tag => s.version.to_s }

  s.ios.deployment_target = '15.1'
  s.swift_version = '5.0'

  s.source_files = '*.swift'

  s.frameworks = 'Foundation'

  s.dependency 'DDNetwork'
end
```

- [ ] **Step 4: 新增 WeChatRN.podspec**

WeChatRN 包含 Swift + ObjC/ObjC++ 混编文件。需要声明对 React-Core 和 ReactCommon 的依赖以找到 RN 头文件。同时需要 `public_header_files` 暴露 `.h` 文件。

```ruby
Pod::Spec.new do |s|
  s.name             = 'WeChatRN'
  s.version          = '1.0.0'
  s.summary          = '微信 React Native 集成层'
  s.description      = 'RN 容器、TurboModule Bridge、Bundle 热更新、事件系统。'
  s.homepage         = 'https://github.com/nicedayzhu/WeChatSwift'
  s.license          = { :type => 'MIT' }
  s.author           = { 'nicedayzhu' => 'nicedayzhu@example.com' }
  s.source           = { :git => '', :tag => s.version.to_s }

  s.ios.deployment_target = '15.1'
  s.swift_version = '5.0'

  s.source_files = '**/*.{swift,h,m,mm}'
  s.public_header_files = '**/*.h'

  s.frameworks = 'UIKit', 'Foundation'

  s.dependency 'WeChatNetAPI'
  s.dependency 'WeChatUI'
  s.dependency 'WeChatRouter'
  s.dependency 'NavigateKit'
  s.dependency 'React-Core'
  s.dependency 'ReactCommon'
  s.dependency 'ReactCodegen'
  s.dependency 'React_RCTAppDelegate'
  s.dependency 'React-RCTAppDelegate'
end
```

> 注意：`React-Core`、`ReactCommon`、`ReactCodegen`、`React_RCTAppDelegate`/`React-RCTAppDelegate` 这些依赖名称需要在 `pod install` 后根据实际报错微调。RN 的 pod 命名在不同版本间可能有差异。

- [ ] **Step 5: Commit**

```bash
git add Modules/WeChatKit/WeChatUI/WeChatUI.podspec Modules/WeChatKit/WeChatRouter/WeChatRouter.podspec Modules/WeChatKit/WeChatNetAPI/WeChatNetAPI.podspec Modules/WeChatKit/WeChatRN/WeChatRN.podspec
git commit -m "feat: Platform 层 podspec（WeChatUI, WeChatRouter, WeChatNetAPI, WeChatRN）"
```

---

## Task 4: Business 层 podspec（ChatModule, ContactModule, DiscoverModule, MeModule）

**Files:**
- Create: `Modules/Business/ChatModule/ChatModule.podspec`
- Create: `Modules/Business/ContactModule/ContactModule.podspec`
- Create: `Modules/Business/DiscoverModule/DiscoverModule.podspec`
- Create: `Modules/Business/MeModule/MeModule.podspec`

- [ ] **Step 1: ���增 ChatModule.podspec**

```ruby
Pod::Spec.new do |s|
  s.name             = 'ChatModule'
  s.version          = '1.0.0'
  s.summary          = '聊天业务模块'
  s.description      = '聊天列表、聊天详情、消息数据模型。'
  s.homepage         = 'https://github.com/nicedayzhu/WeChatSwift'
  s.license          = { :type => 'MIT' }
  s.author           = { 'nicedayzhu' => 'nicedayzhu@example.com' }
  s.source           = { :git => '', :tag => s.version.to_s }

  s.ios.deployment_target = '15.1'
  s.swift_version = '5.0'

  s.source_files = '**/*.swift'

  s.frameworks = 'UIKit', 'Foundation'

  s.dependency 'WeChatUI'
  s.dependency 'WeChatRouter'
  s.dependency 'WeChatRN'
  s.dependency 'ExtensionKit'
  s.dependency 'SnapKit'
end
```

- [ ] **Step 2: 新增 ContactModule.podspec**

```ruby
Pod::Spec.new do |s|
  s.name             = 'ContactModule'
  s.version          = '1.0.0'
  s.summary          = '通讯录业务模块'
  s.description      = '联系人列表、联系人详情。'
  s.homepage         = 'https://github.com/nicedayzhu/WeChatSwift'
  s.license          = { :type => 'MIT' }
  s.author           = { 'nicedayzhu' => 'nicedayzhu@example.com' }
  s.source           = { :git => '', :tag => s.version.to_s }

  s.ios.deployment_target = '15.1'
  s.swift_version = '5.0'

  s.source_files = '**/*.swift'

  s.frameworks = 'UIKit', 'Foundation'

  s.dependency 'WeChatUI'
  s.dependency 'WeChatRouter'
  s.dependency 'ExtensionKit'
  s.dependency 'SnapKit'
end
```

- [ ] **Step 3: 新增 DiscoverModule.podspec**

```ruby
Pod::Spec.new do |s|
  s.name             = 'DiscoverModule'
  s.version          = '1.0.0'
  s.summary          = '发现业务模块'
  s.description      = '朋友圈、扫一扫、搜索、附近、购物、游戏、摇一摇、视频号。'
  s.homepage         = 'https://github.com/nicedayzhu/WeChatSwift'
  s.license          = { :type => 'MIT' }
  s.author           = { 'nicedayzhu' => 'nicedayzhu@example.com' }
  s.source           = { :git => '', :tag => s.version.to_s }

  s.ios.deployment_target = '15.1'
  s.swift_version = '5.0'

  s.source_files = '**/*.swift'

  s.frameworks = 'UIKit', 'Foundation'

  s.dependency 'WeChatUI'
  s.dependency 'WeChatRouter'
  s.dependency 'WeChatRN'
  s.dependency 'ExtensionKit'
  s.dependency 'SnapKit'
end
```

- [ ] **Step 4: 新增 MeModule.podspec**

```ruby
Pod::Spec.new do |s|
  s.name             = 'MeModule'
  s.version          = '1.0.0'
  s.summary          = '我的页业务模块'
  s.description      = '个人资料、设置。'
  s.homepage         = 'https://github.com/nicedayzhu/WeChatSwift'
  s.license          = { :type => 'MIT' }
  s.author           = { 'nicedayzhu' => 'nicedayzhu@example.com' }
  s.source           = { :git => '', :tag => s.version.to_s }

  s.ios.deployment_target = '15.1'
  s.swift_version = '5.0'

  s.source_files = '**/*.swift'

  s.frameworks = 'UIKit', 'Foundation'

  s.dependency 'WeChatUI'
  s.dependency 'WeChatRouter'
  s.dependency 'WeChatNetAPI'
  s.dependency 'ExtensionKit'
  s.dependency 'SnapKit'
end
```

- [ ] **Step 5: Commit**

```bash
git add Modules/Business/ChatModule/ChatModule.podspec Modules/Business/ContactModule/ContactModule.podspec Modules/Business/DiscoverModule/DiscoverModule.podspec Modules/Business/MeModule/MeModule.podspec
git commit -m "feat: Business 层 podspec（ChatModule, ContactModule, DiscoverModule, MeModule）"
```

---

## Task 5: 重写 Podfile

**Files:**
- Modify: `Podfile`

- [ ] **Step 1: 重写 Podfile**

将整个 `Podfile` 替换为以下内容：

```ruby
# WeChatSwift Podfile
#
# 架构：Soul 式单 target 扁平模式
#   - 所有 pod（自有模块 + 三方库）统一声明在 app target
#   - 模块间依赖关系由各自 .podspec 的 dependency ���理
#   - use_frameworks! :linkage => :static 全静态链接

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
  # ── Foundation 层 ──
  pod 'ExtensionKit',   :path => 'Foundation/ExtensionKit'
  pod 'NavigateKit',    :path => 'Foundation/NavigateKit'
  pod 'DDNetwork',      :path => 'Foundation/DDNetwork'

  # ── Platform 层 ──
  pod 'WeChatUI',       :path => 'Modules/WeChatKit/WeChatUI'
  pod 'WeChatRouter',   :path => 'Modules/WeChatKit/WeChatRouter'
  pod 'WeChatNetAPI',   :path => 'Modules/WeChatKit/WeChatNetAPI'
  pod 'WeChatRN',       :path => 'Modules/WeChatKit/WeChatRN'

  # ── Business 层 ──
  pod 'ChatModule',     :path => 'Modules/Business/ChatModule'
  pod 'ContactModule',  :path => 'Modules/Business/ContactModule'
  pod 'DiscoverModule', :path => 'Modules/Business/DiscoverModule'
  pod 'MeModule',       :path => 'Modules/Business/MeModule'

  # ── 三方库 ──
  pod 'SnapKit'

  # ── RN ──
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

- [ ] **Step 2: Commit**

```bash
git add Podfile
git commit -m "feat: 重写 Podfile 为单 target 扁平模式 + 静态链接"
```

---

## Task 6: 精简 project.yml

**Files:**
- Modify: `project.yml`

- [ ] **Step 1: 精简 project.yml 为只保留 app target**

将整个 `project.yml` 替换为以下内容：

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
        CFBundleDevelopmentRegion: zh_CN
        CFBundleDisplayName: 微信
        CFBundleExecutable: $(EXECUTABLE_NAME)
        CFBundleIdentifier: $(PRODUCT_BUNDLE_IDENTIFIER)
        CFBundleInfoDictionaryVersion: "6.0"
        CFBundleName: $(PRODUCT_NAME)
        CFBundlePackageType: APPL
        CFBundleShortVersionString: "1.0"
        CFBundleVersion: "1"
        LSRequiresIPhoneOS: true
        UIApplicationSceneManifest:
          UIApplicationSupportsMultipleScenes: false
          UISceneConfigurations:
            UIWindowSceneSessionRoleApplication:
              - UISceneConfigurationName: Default Configuration
                UISceneDelegateClassName: $(PRODUCT_MODULE_NAME).SceneDelegate
        UILaunchScreen:
          UIColorName: ""
          UIImageName: ""
        UISupportedInterfaceOrientations:
          - UIInterfaceOrientationPortrait
        UIUserInterfaceStyle: Light
        NSAppTransportSecurity:
          NSAllowsLocalNetworking: true
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

- [ ] **Step 2: Commit**

```bash
git add project.yml
git commit -m "refactor: 精简 project.yml 为单 app target"
```

---

## Task 7: 执行 setup 并修复编译问题

**Files:**
- 可能修改: `Modules/WeChatKit/WeChatRN/WeChatRN.podspec`（根据编译报错调整 RN 依赖名）
- 可能修改: 其他 podspec（根据 source_files 路径报错调整）

- [ ] **Step 1: 执行 xcodegen + pod install**

```bash
./setup.sh
```

预期输出：xcodegen 生成 xcodeproj，pod install 安装所有 pod。

如果 `pod install` 报错，进入 Step 2 排查。如果成功，跳到 Step 3。

- [ ] **Step 2: 修复 pod install 报错**

常见报错及对应修复：

**报错：`Unable to find a specification for 'React-Core'`**
→ `React-Core` 已由 `use_react_native!` 注册，但名称可能不同。检查 `Podfile.lock` 或 `Pods/` 中实际的 RN pod 名称，修正 `WeChatRN.podspec` 中的 dependency。

**报错：`[!] The 'Pods-WeChatSwift' target has frameworks with conflicting names: xxx`**
→ 某个本地 pod 名称与已有 pod 冲突，需要改名。

**报错：`source_files pattern did not match any file`**
→ podspec 的 source_files 路径不对，根据报错修正 glob 模式。

修复后重新执行：

```bash
pod install
```

- [ ] **Step 3: Xcode 编译验证**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'generic/platform=iOS Simulator' -quiet
```

预期：BUILD SUCCEEDED

如果编译失败，根据报错定位问题（通常是 header 找不到或链接错误），修正对应 podspec 后重新 `pod install` → 编译。

- [ ] **Step 4: Commit 所有修复**

```bash
git add -A
git commit -m "fix: 修复 pod install 和编译��题"
```

---

## Task 8: 清理旧文件 + 最终验证

**Files:**
- Delete: `Podfile.lock`（会由 pod install 重新生成）

- [ ] **Step 1: 清理并重新安装**

```bash
rm -rf Pods Podfile.lock
./setup.sh
```

- [ ] **Step 2: Xcode 编译验证**

```bash
xcodebuild build -workspace WeChatSwift.xcworkspace -scheme WeChatSwift -destination 'generic/platform=iOS Simulator' -quiet
```

预期��BUILD SUCCEEDED

- [ ] **Step 3: 在 Xcode 中打开工程，确认模块在 Development Pods 下可见**

```bash
open WeChatSwift.xcworkspace
```

检查点：
- Pods 项目下 Development Pods 包含 11 个本地模块
- 三方库（SnapKit 等）在 Pods 分组下
- app target（WeChatSwift）能正常 Run 到模拟器

- [ ] **Step 4: 最终 Commit**

```bash
git add Podfile.lock
git commit -m "chore: 静态库 + podspec 模块化迁移完成"
```
