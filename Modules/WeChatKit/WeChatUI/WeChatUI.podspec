Pod::Spec.new do |s|
  s.name             = 'WeChatUI'
  s.version          = '1.0.0'
  s.summary          = '微信 UI 基础组件库'
  s.description      = '主题、基础 ViewController、通用 UI 组件。'
  s.homepage         = 'https://github.com/nicedayzhu/WeChatSwift'
  s.license          = { :type => 'MIT' }
  s.author           = { 'nicedayzhu' => 'nicedayzhu@example.com' }
  s.source           = { :git => '', :tag => s.version.to_s }

  s.ios.deployment_target = '15.1'
  s.swift_version = '5.0'

  s.source_files = 'Base/**/*.swift', 'Theme/**/*.swift', 'WeChatUI.swift'

  s.frameworks = 'UIKit', 'Foundation'

  s.dependency 'ExtensionKit'
  s.dependency 'SnapKit'
end
