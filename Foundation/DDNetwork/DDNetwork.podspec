Pod::Spec.new do |s|
  s.name             = 'DDNetwork'
  s.version          = '1.0.0'
  s.summary          = '网络请求基础库'
  s.description      = '通用网络层，提供 API 请求、拦截器、响应解码等能力。'
  s.homepage         = 'https://github.com/nicedayzhu/WeChatSwift'
  s.license          = { :type => 'MIT' }
  s.author           = { 'nicedayzhu' => 'nicedayzhu@example.com' }
  s.source           = { :git => '', :tag => s.version.to_s }

  s.ios.deployment_target = '15.1'
  s.swift_version = '5.0'

  s.source_files = 'Core/**/*.swift', 'Models/**/*.swift', 'Interceptors/**/*.swift', 'Build/**/*.swift'

  s.frameworks = 'Foundation'
end
