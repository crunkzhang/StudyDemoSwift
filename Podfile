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
  pod 'CatonMonitorKit', :path => 'Foundation/CatonMonitorKit'

  # ── Platform 层 ──
  pod 'WeChatUI',       :path => 'Modules/WeChatKit/WeChatUI'
  pod 'WeChatRouter',   :path => 'Modules/WeChatKit/WeChatRouter'
  pod 'WeChatNetAPI',   :path => 'Modules/WeChatKit/WeChatNetAPI'
  pod 'WeChatRN',       :path => 'Modules/WeChatKit/WeChatRN'
  pod 'WCIMSDK',        :path => 'Modules/Platform/WCIMSDK'

  # ── Business 层 ──
  pod 'ChatModule',     :path => 'Modules/Business/ChatModule'
  pod 'ContactModule',  :path => 'Modules/Business/ContactModule'
  pod 'DiscoverModule', :path => 'Modules/Business/DiscoverModule'
  pod 'MeModule',       :path => 'Modules/Business/MeModule'
  pod 'GameModule',     :path => 'Modules/Business/GameModule'

  # ── 三方库 ──
  pod 'SnapKit'
  pod 'SDWebImage'
  pod 'ZIPFoundation'

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

  # 把 RN 相关 pod 从 Development Pods 收拢到 "RN" 子分组，
  # 自有模块留在顶层，Xcode Navigator 更清爽。
  # Xcode Navigator 分组：按层次归类，折叠后一目了然
  group_map = {
    'Platform'   => %w[WeChatUI WeChatRouter WeChatNetAPI WeChatRN WCIMSDK],
    'Foundation' => %w[ExtensionKit NavigateKit DDNetwork CatonMonitorKit],
    'Business'   => %w[ChatModule ContactModule DiscoverModule MeModule GameModule],
  }
  own_pods = group_map.values.flatten
  pods_proj = installer.pods_project
  dev_group = pods_proj.main_group.children.find { |g| g.name == 'Development Pods' }
  if dev_group
    # 自有模块按层分组
    group_map.each do |name, pods|
      sub = dev_group.new_group(name)
      pods.each do |pod_name|
        child = dev_group.children.find { |c| c.name == pod_name }
        child.move(sub) if child
      end
    end
    # RN 相关收拢
    rn_group = dev_group.new_group('RN')
    children_to_move = dev_group.children.select { |c|
      !%w[Foundation Platform Business RN].include?(c.name) && c != rn_group
    }
    children_to_move.each { |c| c.move(rn_group) }
    pods_proj.save
  end

  # CocoaPods 会在 post_install 之后再次 save，覆盖 group 排序。
  # 用 at_exit 在进程退出前重新排序 pbxproj 文件。
  at_exit do
    require 'xcodeproj'
    proj = Xcodeproj::Project.open('Pods/Pods.xcodeproj')
    dev = proj.main_group.children.find { |g| g.name == 'Development Pods' }
    if dev
      desired_order = ['Business', 'Platform', 'Foundation', 'RN']
      sorted = dev.children.sort_by { |c| desired_order.index(c.name) || 999 }
      dev.children.clear
      sorted.each { |c| dev.children << c }
      proj.save
    end
  end
end
