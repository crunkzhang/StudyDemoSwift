Pod::Spec.new do |s|
  s.name             = 'NavigateKit'
  s.version          = '1.0.0'
  s.summary          = 'Swift 页面跳转工具'
  s.description      = 'NavigateKit 提供纯页面跳转能力，不包含路由注册逻辑。'
  s.homepage         = 'https://github.com/yourname/NavigateKit'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Your Name' => 'your.email@example.com' }
  s.source           = { :git => 'https://github.com/yourname/NavigateKit.git', :tag => s.version.to_s }

  s.ios.deployment_target = '15.1'
  s.swift_version = '5.0'

  s.source_files = '**/*.swift'

  s.frameworks = 'UIKit', 'Foundation'
end
