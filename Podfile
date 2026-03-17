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

  post_install do |installer|
    react_native_post_install(
      installer,
      rn_path,
      :mac_catalyst_enabled => false,
    )
  end
end

# 基础组件层
target 'ExtensionKit' do
end

target 'RouterKit' do
end

target 'WeChatUI' do
  shared_pods
end

target 'WeChatRouter' do
end

target 'WeChatBridge' do
  rn_path = '../WeChatRN/node_modules/react-native'
  use_react_native!(
    :path => rn_path,
    :app_path => rn_project
  )
end

# 业务模块层
target 'ChatModule' do
  rn_path = '../WeChatRN/node_modules/react-native'
  use_react_native!(
    :path => rn_path,
    :app_path => rn_project
  )
  shared_pods
end

target 'ContactModule' do
  shared_pods
end

target 'DiscoverModule' do
  shared_pods
end

target 'MeModule' do
  shared_pods
end
