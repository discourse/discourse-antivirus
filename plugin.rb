# frozen_string_literal: true

# name: discourse-antivirus
# about: Scan your Discourse uploads using ClamAV
# version: 0.1
# authors: romanrizzi
# url: https://github.com/discourse/discourse-antivirus

gem "dns-sd", "0.1.3"

enabled_site_setting :discourse_antivirus_enabled

register_asset "stylesheets/reviewable-upload.scss"
register_asset "stylesheets/antivirus-stats.scss"

module ::DiscourseAntivirus
  PLUGIN_NAME = "discourse-antivirus"
end

require_relative "lib/discourse_antivirus/engine"

add_admin_route("antivirus.title", "discourse-antivirus", { use_new_show_route: true })

after_initialize do
  register_reviewable_type ReviewableUpload

  add_to_serializer(
    :site,
    :clamav_unreacheable,
    respect_plugin_enabled: false,
    include_condition: -> { SiteSetting.discourse_antivirus_enabled? && scope.is_staff? },
  ) do
    !!PluginStore.get(
      DiscourseAntivirus::ClamAv::PLUGIN_NAME,
      DiscourseAntivirus::ClamAv::UNAVAILABLE,
    )
  end

  on(:site_setting_changed) do |name, _, new_val|
    Jobs.enqueue(:fetch_antivirus_version) if name == :discourse_antivirus_enabled && new_val
  end

  on(:before_upload_creation) do |file, is_image, upload, validate|
    should_scan_file = !upload.for_export && (!is_image || SiteSetting.antivirus_live_scan_images)

    if validate && should_scan_file && upload.valid?
      antivirus = DiscourseAntivirus::ClamAv.instance

      response = antivirus.scan_file(file)
      is_positive = response[:found]

      upload.errors.add(:base, I18n.t("scan.virus_found")) if is_positive
    end
  end

  if defined?(::DiscoursePrometheus)
    require_relative "lib/discourse_antivirus/clam_av_health_metric.rb"

    DiscoursePluginRegistry.register_global_collector(DiscourseAntivirus::ClamAvHealthMetric, self)
  end

  add_reviewable_score_link(:malicious_file, "plugin:discourse-antivirus")
end
