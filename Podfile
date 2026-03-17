# WeChatSwift Podfile — integrates React Native from WeChatRN

rn_project = File.expand_path('../WeChatRN', __dir__)

require Pod::Executable.execute_command('node', ['-p',
  'require.resolve(
    "react-native/scripts/react_native_pods.rb",
    {paths: [process.argv[1]]},
  )', rn_project]).strip

platform :ios, '15.1'
prepare_react_native_project!

linkage = ENV['USE_FRAMEWORKS']
if linkage != nil
  Pod::UI.puts "Configuring Pod with #{linkage}ally linked Frameworks".green
  use_frameworks! :linkage => linkage.to_sym
end

# Foundation 二方库（本地开发）
pod 'ExtensionKit', :path => './Foundation/ExtensionKit'
pod 'RouterKit', :path => './Foundation/RouterKit'

# 共享的 pods
def shared_pods
  pod 'SnapKit'
end

target 'WeChatSwift' do
  rn_path = '../WeChatRN/node_modules/react-native'

  use_react_native!(
    :path => rn_path,
    :app_path => rn_project
  )

  # Manually autolink native modules (paths relative to this Podfile)
  pod 'react-native-safe-area-context', :path => '../WeChatRN/node_modules/react-native-safe-area-context'
  shared_pods

  # 主工程也需要访问 Foundation 二方库
  pod 'ExtensionKit', :path => './Foundation/ExtensionKit'
  pod 'RouterKit', :path => './Foundation/RouterKit'

  post_install do |installer|
    react_native_post_install(
      installer,
      rn_path,
      :mac_catalyst_enabled => false,
    )
  end
end

# 基础组件层（现在作为外部依赖引入，不需要单独的 target）
# ExtensionKit 和 RouterKit 已通过 pod 引入

target 'WeChatUI' do
  shared_pods
  # 依赖 Foundation 二方库
  pod 'ExtensionKit', :path => './Foundation/ExtensionKit'
end

target 'WeChatRouter' do
  # 依赖 Foundation 二方库
  pod 'RouterKit', :path => './Foundation/RouterKit'
end

target 'WeChatRNKit' do
  rn_path = '../WeChatRN/node_modules/react-native'
  use_react_native!(
    :path => rn_path,
    :app_path => rn_project
  )
  shared_pods
end

# 业务模块层
target 'ChatModule' do
  rn_path = '../WeChatRN/node_modules/react-native'
  use_react_native!(
    :path => rn_path,
    :app_path => rn_project
  )
  shared_pods
  # 依赖 Foundation 二方库
  pod 'ExtensionKit', :path => './Foundation/ExtensionKit'
  pod 'RouterKit', :path => './Foundation/RouterKit'
end

target 'ContactModule' do
  shared_pods
  # 依赖 Foundation 二方库
  pod 'ExtensionKit', :path => './Foundation/ExtensionKit'
  pod 'RouterKit', :path => './Foundation/RouterKit'
end

target 'DiscoverModule' do
  shared_pods
  # 依赖 Foundation 二方库
  pod 'ExtensionKit', :path => './Foundation/ExtensionKit'
  pod 'RouterKit', :path => './Foundation/RouterKit'
end

target 'MeModule' do
  shared_pods
  # 依赖 Foundation 二方库
  pod 'ExtensionKit', :path => './Foundation/ExtensionKit'
  pod 'RouterKit', :path => './Foundation/RouterKit'
end
