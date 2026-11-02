Pod::Spec.new do |s|
  s.name             = 'radio_pcm'
  s.version          = '0.0.1'
  s.summary          = 'Decode an internet radio stream to PCM for speech recognition.'
  s.description      = <<-DESC
Opens a radio stream (Icecast, Shoutcast or HLS) on its own connection and
decodes it to 16 kHz mono Float32 samples with AudioToolbox, for RadioPod's
offline captions.
                       DESC
  s.homepage         = 'https://github.com/gjwgit/radiopod'
  s.license          = { :type => 'GPL-3.0' }
  s.author           = { 'Togaware Pty Ltd' => 'support@togaware.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'radio_pcm/Sources/radio_pcm/**/*.swift'
  s.ios.dependency 'Flutter'
  s.osx.dependency 'FlutterMacOS'
  s.ios.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
  s.frameworks       = 'AVFoundation', 'AudioToolbox'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version    = '5.0'
end
