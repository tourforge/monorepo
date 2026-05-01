# common_podfile.rb - Shared Podfile logic for TourForge apps

def apply_tourforge_configs(installer)
  installer.pods_project.targets.each do |target|
    # Standard Flutter setup
    if defined? flutter_additional_ios_build_settings
      flutter_additional_ios_build_settings(target)
    end

    # Shared build settings
    target.build_configurations.each do |config|
      config.build_settings["ONLY_ACTIVE_ARCH"] = "YES"
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
    end
  end
end
