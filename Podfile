source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '18.2'
use_modular_headers!

inhibit_all_warnings!

post_install do |installer|
  installer.pods_project.build_configurations.each do |config|
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '18.2'
    config.build_settings['ENABLE_BITCODE'] = 'NO'
    config.build_settings['SWIFT_VERSION'] = '5.0'
    config.build_settings['ONLY_ACTIVE_ARCH'] = 'YES'
    config.build_settings['VALID_ARCHS'] = 'arm64 arm64e'
    # 添加沙盒权限
    config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
  end
end

target 'Xdnmb' do
  # Comment the next line if you don't want to use dynamic frameworks
  # use_frameworks!

  pod 'SnapKit'
  pod 'AFNetworking'
  pod 'LookinServer', :configurations => ['Debug']

end
