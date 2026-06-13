source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '18.2'
use_modular_headers!

inhibit_all_warnings!

target 'Xdnmb' do
  pod 'SnapKit'
  pod 'Alamofire', '~> 5.9'
  pod 'LookinServer', :configurations => ['Debug']
end

post_install do |installer|
  installer.pods_project.build_configurations.each do |config|
    config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '18.2'
    config.build_settings['SWIFT_VERSION'] = '5.0'
    config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
  end
  # Also disable sandbox on main target
  installer.generated_aggregate_targets.each do |target|
    target.xcconfigs.each do |config_name, config_file|
      # handled by pods
    end
  end
end
