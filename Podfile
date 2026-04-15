# WeChatSwift Podfile
#
# 依赖架构（单向向下）:
#   App Layer:        WeChatSwift（纯壳，不持有任何三方库）
#   Feature Layer:    ChatModule / ContactModule / DiscoverModule / MeModule
#   Platform Layer:   WeChatUI(SnapKit) / WeChatRN(RN pods) / WeChatRouter / WeChatNetAPI
#   Foundation Layer: DDNetwork
#
# 三方库归属:
#   SnapKit  → WeChatUI 唯一持有
#   RN pods  → WeChatRN 唯一持有
#
# 使用 dynamic frameworks 确保每个 pod 只编译一份，零重复。

rn_project = File.expand_path('../WeChatRN', __dir__)
rn_path    = '../WeChatRN/node_modules/react-native'

require Pod::Executable.execute_command('node', ['-p',
  'require.resolve(
    "react-native/scripts/react_native_pods.rb",
    {paths: [process.argv[1]]},
  )', rn_project]).strip

platform :ios, '15.1'
prepare_react_native_project!
use_frameworks! :linkage => :dynamic

# ========== Platform 层 ==========

target 'WeChatUI' do
  pod 'SnapKit'

  # WeChatRN 唯一持有所有 RN pods，继承 SnapKit 搜索路径
  target 'WeChatRN' do
    inherit! :search_paths
    use_react_native!(:path => rn_path, :app_path => rn_project)
    pod 'react-native-safe-area-context', :path => '../WeChatRN/node_modules/react-native-safe-area-context'
    pod 'RNScreens', :path => '../WeChatRN/node_modules/react-native-screens'
    pod 'react-native-webview', :path => '../WeChatRN/node_modules/react-native-webview'
    pod 'RNSVG', :path => '../WeChatRN/node_modules/react-native-svg'
  end

  # ========== Feature 层 ==========
  # 业务模块只继承搜索路径，通过 WeChatUI 间接使用 SnapKit

  target 'ChatModule' do
    inherit! :search_paths
  end

  target 'ContactModule' do
    inherit! :search_paths
  end

  target 'DiscoverModule' do
    inherit! :search_paths
  end

  target 'MeModule' do
    inherit! :search_paths
  end
end

# ========== App 层 ==========
# 纯壳：不持有任何三方库，只启动和装配

target 'WeChatSwift' do
end

post_install do |installer|
  react_native_post_install(
    installer,
    rn_path,
    :mac_catalyst_enabled => false,
  )
end
