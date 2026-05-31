Pod::Spec.new do |s|
  s.name             = 'DSLKit'
  s.version          = '1.0.0'
  s.summary          = '动态化页面引擎(SDUI):JSON 描述 → 原生渲染 → OSS 热更'
  s.description      = 'DSL/JSON 驱动的页面渲染引擎,支持组件注册、向前兼容、灰度、回滚。首发用于「我的」页。'
  s.homepage         = 'https://github.com/nicedayzhu/WeChatSwift'
  s.license          = { :type => 'MIT' }
  s.author           = { 'nicedayzhu' => 'nicedayzhu@example.com' }
  s.source           = { :git => '', :tag => s.version.to_s }

  s.ios.deployment_target = '15.1'
  s.swift_version = '5.0'

  s.source_files = '**/*.swift'
  s.exclude_files = 'DSLKitTests/**/*'
  s.resources = ['Resources/**/*']

  s.frameworks = 'UIKit', 'Foundation'

  s.dependency 'WeChatUI'
  s.dependency 'WeChatRouter'
  s.dependency 'NavigateKit'
  s.dependency 'ExtensionKit'
  s.dependency 'SnapKit'

  s.test_spec 'DSLKitTests' do |ts|
    ts.source_files = 'DSLKitTests/**/*.swift'
    ts.frameworks = 'XCTest'
  end
end
