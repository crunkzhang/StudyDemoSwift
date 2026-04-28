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
