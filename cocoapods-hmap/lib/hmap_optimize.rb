=begin
This plugin modifies HEADER_SEARCH_PATHS in Pods/Target Support Files/*/*.xcconfig
combining "${PODS_ROOT}/Headers/Public/*" to a single hmap. (not including ${PODS_ROOT}/Headers/Public itself)
=end

module Pod
  class Target
    class BuildSettings
      attr_accessor :hmap_md5
    end
  end

  class Installer
    # helper functions
    def to_remove?(header_search_path)
      header_search_path.include?("${PODS_ROOT}/Headers/Public/")
    end

    def headers_for_path(path)
      @cached_headers ||= {}
      cached = @cached_headers.fetch(path, {})
      return cached unless cached.blank?

      full_path = path.sub(/^\$\{PODS_ROOT\}/, sandbox.root.to_s)
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

    def create_hmap(build_settings)
      header_search_paths = build_settings.header_search_paths
      return if header_search_paths.blank?

      convert_paths = header_search_paths.select { |p| to_remove?(p) }
      return if convert_paths.blank?

      convert_paths_string = convert_paths.join(" ")&.strip
      md5_string = Digest::MD5.hexdigest(convert_paths_string)

      UI.message "md5(#{convert_paths_string})=#{md5_string}"

      hmap_dir = File.expand_path("Headers/hmap", sandbox.root.to_s)
      hmap_path = File.expand_path("#{md5_string}.hmap", hmap_dir)
      if File.exist?(hmap_path)
        build_settings.hmap_md5 = md5_string
        return
      end

      header_path_hash = convert_paths.map { |x| headers_for_path(x) }.inject(:merge)
      return if header_path_hash.blank?

      begin
        FileUtils.mkdir_p(hmap_dir) unless File.directory?(hmap_dir)
        json_path = File.expand_path("#{md5_string}.json", hmap_dir)
        File.open(json_path, 'w') do |file|
          file << header_path_hash.to_json
        end

        convert_json_to_hmap(json_path, hmap_path)
        File.delete(json_path)

        build_settings.hmap_md5 = md5_string
        UI.message "created hmap #{hmap_path}"
      rescue => e
        UI.warn "create hmap error: #{e.inspect}"
      end
    end

    def convert_json_to_hmap(public_json, public_hmap)
      hmap = File.expand_path("hmap", File.dirname(__FILE__ ))
      `#{hmap} convert '#{public_json}' '#{public_hmap}' `
    end

    def handle_target_with_settings(build_settings, xcconfig, xcconfig_path)
      return if build_settings.blank? || build_settings.hmap_md5.blank?

      hmap_path = File.expand_path("Headers/hmap/#{build_settings.hmap_md5}.hmap", sandbox.root.to_s)
      return unless File.exist?(hmap_path)

      hmap_item = "\"${PODS_ROOT}/Headers/hmap/#{build_settings.hmap_md5}.hmap\""

      header_search_paths = xcconfig.to_hash['HEADER_SEARCH_PATHS']
      path_items = header_search_paths.split(/\s+/)

      keep_paths = path_items.reject { |p| to_remove?(p) }
      keep_paths << hmap_item

      new_header_search_paths = keep_paths.join(" ")
      xcconfig.attributes['HEADER_SEARCH_PATHS'] = new_header_search_paths
      xcconfig.save_as(xcconfig_path)
    end

    # hook point
    alias_method :_old_run_podfile_post_install_hook, :run_podfile_post_install_hook
    def run_podfile_post_install_hook
      # 生成 hmap file，然后修改 xcconfig 文件
      aggregate_targets.each do |aggregate_target|
        UI.message "convert hmap for aggregate_target #{aggregate_target}"
        aggregate_target.user_build_configurations.each_key do |config| # "Debug" => :debug
          build_settings = aggregate_target.build_settings(config) # AggregateTargetSettings
          create_hmap(build_settings)

          xcconfig_path = aggregate_target.xcconfig_path(config)
          xcconfig = aggregate_target.xcconfigs[config]
          handle_target_with_settings(build_settings, xcconfig, xcconfig_path)
        end
      end

      pod_targets.each do |pod_target|
        UI.message "convert hmap for pod_target #{pod_target}"
        pod_target.build_settings.each do |config, build_settings| # "Debug" => PodTargetSettings
          create_hmap(build_settings)

          xcconfig_path = pod_target.xcconfig_path(config)
          xcconfig = Xcodeproj::Config.new(xcconfig_path)
          handle_target_with_settings(build_settings, xcconfig, xcconfig_path)
        end
      end

      _old_run_podfile_post_install_hook
    end

  end
end
