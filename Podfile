# WeChatSwift Podfile

rn_project = File.expand_path('../WeChatRN', __dir__)
rn_path    = '../WeChatRN/node_modules/react-native'

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

# ========== 主工程 ==========

target 'WeChatSwift' do
  use_react_native!(:path => rn_path, :app_path => rn_project)
  pod 'react-native-safe-area-context', :path => '../WeChatRN/node_modules/react-native-safe-area-context'
  pod 'RNScreens', :path => '../WeChatRN/node_modules/react-native-screens'
  pod 'react-native-webview', :path => '../WeChatRN/node_modules/react-native-webview'
  pod 'SnapKit'

  post_install do |installer|
    react_native_post_install(
      installer,
      rn_path,
      :mac_catalyst_enabled => false,
    )
  end
end

# ========== 业务模块层 ==========

target 'ChatModule' do
  pod 'SnapKit'
end

target 'ContactModule' do
  pod 'SnapKit'
end

target 'DiscoverModule' do
  pod 'SnapKit'
end

target 'MeModule' do
  pod 'SnapKit'
end

# ========== WeChatKit 层 ==========

target 'WeChatUI' do
  pod 'SnapKit'
end

target 'WeChatRouter' do
end

target 'WeChatRN' do
  use_react_native!(:path => rn_path, :app_path => rn_project)
  pod 'RNScreens', :path => '../WeChatRN/node_modules/react-native-screens'
  pod 'react-native-webview', :path => '../WeChatRN/node_modules/react-native-webview'
  pod 'SnapKit'
end
