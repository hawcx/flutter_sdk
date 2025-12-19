Pod::Spec.new do |s|
  s.name             = 'hawcx_flutter_sdk'
  s.version          = '1.0.2'
  s.summary          = 'Hawcx Flutter SDK plugin.'
  s.description      = <<-DESC
A Flutter plugin that wraps the Hawcx native iOS SDK.
                       DESC
  s.homepage         = 'https://hawcx.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Hawcx' => 'support@hawcx.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.exclude_files = 'Frameworks/**/*.h'
  s.vendored_frameworks = 'Frameworks/HawcxFramework.xcframework'
  s.dependency 'Flutter'
  s.platform = :ios, '17.5'
  s.swift_version = '5.9'
end
