platform :ios, "8.0"

source 'https://github.com/CocoaPods/Specs.git'

xcodeproj 'VULCAM eye.xcodeproj'

target 'VULCAM eye' do
  pod 'CocoaAsyncSocket', :git => 'git@github.com:BitKaitsu/CocoaAsyncSocket', :branch => 'master'
  pod 'ios-ntp', :git => 'git@github.com:BitKaitsu/ios-ntp', :branch => 'master'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['SWIFT_VERSION'] = '3.0'
      config.build_settings['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'NO'
    end
  end
end
