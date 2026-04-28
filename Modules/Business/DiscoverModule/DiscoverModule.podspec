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
