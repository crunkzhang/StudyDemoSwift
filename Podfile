# WeChatSwift Podfile
#
# 架构：Soul 式单 target 扁平模式
#   - 所有 pod（自有模块 + 三方库）统一声明在 app target
#   - 模块间依赖关系由各自 .podspec 的 dependency 管理
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

  # generate_multiple_pod_projects 模式下，REACT_NATIVE_PATH 只设置在主项目上，
  # 需要手动传播到各 pod 的独立 xcodeproj，否则 hermes/RNDeps 脚本找不到 with-environment.sh
  rn_absolute = File.join("${PODS_ROOT}", "..", rn_path)
  installer.generated_projects.each do |project|
    project.build_configurations.each do |config|
      config.build_settings["REACT_NATIVE_PATH"] ||= rn_absolute
    end
  end

  # Xcode 26 新链接器（ld-1230）对 use_frameworks! :linkage => :static 生成的
  # 静态 .framework 仍产出 LC_LOAD_DYLIB 动态加载命令，导致运行时 dyld 崩溃。
  # 回退到经典链接器规避此问题。
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      flags = config.build_settings['OTHER_LDFLAGS'] || '$(inherited)'
      unless flags.include?('-ld_classic')
        config.build_settings['OTHER_LDFLAGS'] = "#{flags} -ld_classic"
      end
    end
  end

  # 同时在 app 级 xcconfig 注入 -ld_classic
  Dir.glob(File.join('Pods', 'Target Support Files', 'Pods-WeChatSwift', '*.xcconfig')).each do |xcconfig_path|
    content = File.read(xcconfig_path)
    unless content.include?('-ld_classic')
      content.gsub!(/^(OTHER_LDFLAGS\s*=\s*)(.*)$/) { "#{$1}#{$2} -ld_classic" }
      File.write(xcconfig_path, content)
    end
  end
end
