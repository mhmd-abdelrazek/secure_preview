Pod::Spec.new do |s|
  s.name             = 'secure_preview'
  s.version          = '0.1.0'
  s.summary          = 'Sensitive content preview protection for Flutter.'
  s.description      = 'Best-effort screen capture and device risk signals for Flutter.'
  s.homepage         = 'https://github.com/mhmd-abdelrazek/secure_preview'
  s.license          = { :type => 'MIT' }
  s.author           = { 'secure_preview' => 'mohamed.ahmed.abdelrazek.dev@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '12.0'
  s.swift_version = '5.0'
  s.static_framework = true
end
