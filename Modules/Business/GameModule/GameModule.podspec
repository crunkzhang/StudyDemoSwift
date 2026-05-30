Pod::Spec.new do |s|
  s.name             = 'GameModule'
  s.version          = '1.0.0'
  s.summary          = '游戏中心:H5 大厅 + WebView 小游戏'
  s.description      = '原生 WKWebView 容器,大厅 H5 内置随 app 发版,具体游戏走 OSS 远程下载。'
  s.homepage         = 'https://github.com/nicedayzhu/WeChatSwift'
  s.license          = { :type => 'MIT' }
  s.author           = { 'nicedayzhu' => 'nicedayzhu@example.com' }
  s.source           = { :git => '', :tag => s.version.to_s }

  s.ios.deployment_target = '15.1'
  s.swift_version = '5.0'

  s.source_files = '**/*.swift'
  s.exclude_files = 'GameModuleTests/**/*'
  s.resources = ['Resources/**/*']

  s.frameworks = 'UIKit', 'Foundation', 'WebKit'

  s.dependency 'AIKit'
  s.dependency 'WeChatUI'
  s.dependency 'WeChatRouter'
  s.dependency 'NavigateKit'
  s.dependency 'ExtensionKit'
  s.dependency 'SnapKit'
  s.dependency 'ZIPFoundation'

  s.test_spec 'GameModuleTests' do |ts|
    ts.source_files = 'GameModuleTests/**/*.swift'
    ts.frameworks = 'XCTest'
  end
end
