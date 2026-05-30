Pod::Spec.new do |s|
  s.name             = 'AIKit'
  s.version          = '1.0.0'
  s.summary          = '可插拔 AI 能力层(Claude / Mock)'
  s.description      = 'AIProvider 协议 + ClaudeProvider(Anthropic Messages API)+ MockProvider。'
  s.homepage         = 'https://github.com/nicedayzhu/WeChatSwift'
  s.license          = { :type => 'MIT' }
  s.author           = { 'nicedayzhu' => 'nicedayzhu@example.com' }
  s.source           = { :git => '', :tag => s.version.to_s }

  s.ios.deployment_target = '15.1'
  s.swift_version = '5.0'

  s.source_files = '*.swift'
  s.frameworks = 'Foundation'
end
