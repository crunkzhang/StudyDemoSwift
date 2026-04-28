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
