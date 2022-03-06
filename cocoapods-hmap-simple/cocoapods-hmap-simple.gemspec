
Gem::Specification.new do |spec|
  spec.name = "cocoapods-hmap-simple"
  spec.version = '1.0.1'
  spec.authors = ["shyang"]
  spec.email = ["shaohua0110@yahoo.com"]

  spec.summary = "A simple hmap generating plugin for cocoapods."
  spec.description = "This plugin modifies HEADER_SEARCH_PATHS in Pods/Target Support Files/*/*.xcconfig
  replacing ${PODS_ROOT}/Headers/Public/* with a single hmap to speed up compilation."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.6.0"
  spec.files = ["lib/cocoapods_plugin.rb", "lib/hmap", "lib/hmap_optimize.rb"]
  spec.homepage = 'https://github.com/shyang/cocoapods-hmap'

end
