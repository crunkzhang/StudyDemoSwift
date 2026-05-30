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
  s.exclude_files = 'ChatModuleTests/**/*'

  s.frameworks = 'UIKit', 'Foundation'

  s.dependency 'WeChatUI'
  s.dependency 'WeChatRouter'
  s.dependency 'WeChatRN'
  s.dependency 'ExtensionKit'
  s.dependency 'SnapKit'
  s.dependency 'SDWebImage'
  s.dependency 'WCIMSDK'

  s.test_spec 'ChatModuleTests' do |ts|
    ts.source_files = 'ChatModuleTests/**/*.swift'
    ts.frameworks = 'XCTest'
  end
end
