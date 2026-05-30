Pod::Spec.new do |s|
  s.name             = 'WCIMSDK'
  s.version          = '1.0.0'
  s.summary          = 'IM 通用基础设施 — Service + DB + 变更广播'
  s.description      = 'Platform 层 IM SDK,提供 Sync/Push 服务、WCDB 落库、DBChangeStream 变更广播。'
  s.homepage         = 'https://github.com/nicedayzhu/WeChatSwift'
  s.license          = { :type => 'MIT' }
  s.author           = { 'nicedayzhu' => 'nicedayzhu@example.com' }
  s.source           = { :git => '', :tag => s.version.to_s }

  s.ios.deployment_target = '15.1'
  s.swift_version = '5.0'

  s.source_files = '**/*.swift'
  s.exclude_files = 'WCIMSDKTests/**/*'

  s.frameworks = 'Foundation', 'UIKit'

  s.dependency 'WCDB.swift'

  s.test_spec 'WCIMSDKTests' do |ts|
    ts.source_files = 'WCIMSDKTests/**/*.swift'
    ts.frameworks = 'XCTest'
  end
end
