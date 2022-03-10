=begin
This plugin modifies HEADER_SEARCH_PATHS in Pods/Target Support Files/*/*.xcconfig
combining "${PODS_ROOT}/Headers/Public/*" to a single hmap. (not including ${PODS_ROOT}/Headers/Public itself)
=end

module Pod
  class HmapHelper
    def self.post_install(installer)
      to_remove = -> path { path.include?("${PODS_ROOT}/Headers/Public/") }

      headers_for_path = -> path do
        @cached_headers ||= {}
        cached = @cached_headers.fetch(path, {})
        return cached unless cached.blank?

        full_path = path.sub(/^\$\{PODS_ROOT\}/, installer.sandbox.root.to_s)
        headers = Dir.glob("#{full_path}/**/{*.h,*.hpp}")
        return {} if headers.blank?

        target_headers_hash = headers.to_h do |header|
          prefix  = File.dirname(header)
          relative_dir = prefix.sub(/^#{full_path}/, '').sub(/^\//, '')
          file_name = File.basename(header)
          file_name = File.join(relative_dir, file_name) unless relative_dir.blank?

          sub_header_hash = {}
          sub_header_hash['suffix'] = File.basename(header)
          sub_header_hash['prefix'] = prefix + "/"

          [file_name, sub_header_hash]
        end
        @cached_headers[path] = target_headers_hash
        target_headers_hash
      end

      create_hmap = -> build_settings do
        header_search_paths = build_settings.header_search_paths
        return if header_search_paths.blank?

        convert_paths = header_search_paths.select { |p| to_remove.call(p) }
        return if convert_paths.blank?

        convert_paths_string = convert_paths.join(" ")&.strip
        md5_string = Digest::MD5.hexdigest(convert_paths_string)

        UI.message "md5(#{convert_paths_string})=#{md5_string}"

        hmap_dir = File.expand_path("Headers/hmap", installer.sandbox.root.to_s)
        hmap_path = File.expand_path("#{md5_string}.hmap", hmap_dir)
        if File.exist?(hmap_path)
          return md5_string
        end

        header_path_hash = convert_paths.map { |x| headers_for_path.call(x) }.inject(:merge)
        return if header_path_hash.blank?

        FileUtils.mkdir_p(hmap_dir) unless File.directory?(hmap_dir)
        json_path = File.expand_path("#{md5_string}.json", hmap_dir)
        File.open(json_path, 'w') do |file|
          file << header_path_hash.to_json
        end

        hmap = File.expand_path("hmap", File.dirname(__FILE__ ))
        `#{hmap} convert '#{json_path}' '#{hmap_path}' `
        File.delete(json_path)

        UI.message "created hmap #{hmap_path}"
        return md5_string
      end

      handle_target_with_settings = -> hmap_md5, target, config do
        return if hmap_md5.blank?

        xcconfig_path = target.xcconfig_path(config)
        xcconfig = Xcodeproj::Config.new(xcconfig_path)

        hmap_path = File.expand_path("Headers/hmap/#{hmap_md5}.hmap", installer.sandbox.root.to_s)
        return unless File.exist?(hmap_path)

        hmap_item = "\"${PODS_ROOT}/Headers/hmap/#{hmap_md5}.hmap\""

        header_search_paths = xcconfig.to_hash['HEADER_SEARCH_PATHS']
        path_items = header_search_paths.split(/\s+/)

        keep_paths = path_items.reject { |p| to_remove.call(p) }
        keep_paths << hmap_item

        new_header_search_paths = keep_paths.join(" ")
        xcconfig.attributes['HEADER_SEARCH_PATHS'] = new_header_search_paths
        xcconfig.save_as(xcconfig_path)
      end

      # 生成 hmap file，然后修改 xcconfig 文件
      installer.aggregate_targets.each do |aggregate_target|
        UI.message "convert hmap for aggregate_target #{aggregate_target}"
        aggregate_target.user_build_configurations.each_key do |config| # "Debug" => :debug
          build_settings = aggregate_target.build_settings(config) # AggregateTargetSettings
          hmap_md5 = create_hmap.call(build_settings)
          handle_target_with_settings.call(hmap_md5, aggregate_target, config)
        end
      end

      installer.pod_targets.each do |pod_target|
        UI.message "convert hmap for pod_target #{pod_target}"
        pod_target.build_settings.each do |config, build_settings| # "Debug" => PodTargetSettings
          hmap_md5 = create_hmap.call(build_settings)
          handle_target_with_settings.call(hmap_md5, pod_target, config)
        end
      end
    end
  end
end

# hook point
module Pod
  class Installer
    alias_method :_old_run_podfile_post_install_hook, :run_podfile_post_install_hook
    def run_podfile_post_install_hook
      HmapHelper.post_install(self)

      _old_run_podfile_post_install_hook
    end

  end
end
