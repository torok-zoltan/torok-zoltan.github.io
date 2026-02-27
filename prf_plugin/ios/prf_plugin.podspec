Pod::Spec.new do |s|
  s.name             = 'prf_plugin'
  s.version          = '0.0.1'
  s.summary          = 'WebAuthn PRF plugin for Flutter'
  s.description      = <<-DESC
A Flutter plugin to derive WebAuthn PRF output using passkeys.
Uses ASWebAuthenticationSession to perform the WebAuthn ceremony.
                       DESC
  s.homepage         = 'https://github.com/torok-zoltan/prf_plugin'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Zoltan Torok' => 'author@example.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '16.0'
  s.swift_version    = '5.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
end
