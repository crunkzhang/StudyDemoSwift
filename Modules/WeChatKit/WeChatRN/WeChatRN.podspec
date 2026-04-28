Pod::Spec.new do |s|
  s.name             = 'WeChatRN'
  s.version          = '1.0.0'
  s.summary          = '微信 React Native 集成层'
  s.description      = 'RN 容器、TurboModule Bridge、Bundle 热更新、事件系统。'
  s.homepage         = 'https://github.com/nicedayzhu/WeChatSwift'
  s.license          = { :type => 'MIT' }
  s.author           = { 'nicedayzhu' => 'nicedayzhu@example.com' }
  s.source           = { :git => '', :tag => s.version.to_s }

  s.ios.deployment_target = '15.1'
  s.swift_version = '5.0'

  s.source_files = '**/*.{swift,m,mm}'
  # .h 含 C++ 内容（RCTTurboModule），不能进 modulemap/umbrella header，
  # 通过 preserve_paths 保留文件，ObjC++ 编译时通过 HEADER_SEARCH_PATHS 找到
  s.preserve_paths = '**/*.h'
  s.pod_target_xcconfig = {
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++20',
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/**"',
    'SWIFT_ENABLE_EXPLICIT_MODULES' => 'NO',
  }

  s.frameworks = 'UIKit', 'Foundation'

  s.dependency 'WeChatNetAPI'
  s.dependency 'WeChatUI'
  s.dependency 'WeChatRouter'
  s.dependency 'NavigateKit'
  s.dependency 'React-Core'
  s.dependency 'ReactCommon'
  s.dependency 'ReactCodegen'
  s.dependency 'React-RCTAppDelegate'
  s.dependency 'ReactAppDependencyProvider'
end
