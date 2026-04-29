Pod::Spec.new do |s|
  s.name             = 'CatonMonitorKit'
  s.version          = '1.0.0'
  s.summary          = '企业级卡顿检测框架'
  s.description      = 'RunLoop/FPS/Watchdog 三重检测 + 堆栈采集 + 本地存储 + 上报协议 + Debug 浮窗'
  s.homepage         = 'https://github.com/nicedayzhu/WeChatSwift'
  s.license          = { :type => 'MIT' }
  s.author           = { 'nicedayzhu' => 'nicedayzhu@example.com' }
  s.source           = { :git => '', :tag => s.version.to_s }

  s.ios.deployment_target = '15.1'
  s.swift_version = '5.0'

  s.source_files = '**/*.swift'

  s.frameworks = 'UIKit', 'Foundation', 'QuartzCore'
end
