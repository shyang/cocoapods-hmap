# Uncomment the next line to define a global platform for your project
platform :ios, '10.0'

target 'Example' do

end

target 'ExampleDylib' do
  pod 'Masonry'                     # source pod with .h .m
  pod 'LookinServer', '1.0.0'       # dynamic pod with .framework
  pod 'Weibo_SDK', :git => 'https://github.com/sinaweibosdk/weibo_ios_sdk.git' # static pod with .h .a .bundle

end

pre_install do |installer|
  host_target = installer.aggregate_targets.find { |aggregate_target| !aggregate_target.requires_host_target? }
  host_target.user_build_configurations.keys.each do |config|
    host_target.pod_targets_for_build_configuration(config).delete_if { |pod_target| pod_target.framework_paths.values.flatten.empty? }
  end
end

