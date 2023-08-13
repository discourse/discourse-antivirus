# frozen_string_literal: true

# name: discourse-antivirus
# about: Scan uploads
# version: 0.1
# authors: romanrizzi
# url: https://github.com/discourse/discourse-antivirus

gem "dns-sd", "0.1.3"

enabled_site_setting :discourse_antivirus_enabled
register_asset "stylesheets/reviewable-upload.scss"

PLUGIN_NAME ||= "DiscourseAntivirus"

load File.expand_path("lib/discourse_antivirus/engine.rb", __dir__)
load File.expand_path("lib/validators/enable_discourse_antivirus_validator.rb", __dir__)

add_admin_route "antivirus.title", "antivirus"

after_initialize do
  require_relative "app/controllers/discourse_antivirus/antivirus_controller.rb"
  require_relative "lib/discourse_antivirus/clamav_services_pool.rb"
  require_relative "lib/discourse_antivirus/clamav_service.rb"
  require_relative "lib/discourse_antivirus/clamav.rb"
  require_relative "lib/discourse_antivirus/background_scan.rb"
  require_relative "models/scanned_upload.rb"
  require_relative "models/reviewable_upload.rb"
  require_relative "serializers/reviewable_upload_serializer.rb"
  require_relative "jobs/scheduled/scan_batch.rb"
  require_relative "jobs/scheduled/create_scanned_uploads.rb"
  require_relative "jobs/scheduled/fetch_antivirus_version.rb"
  require_relative "jobs/scheduled/remove_orphaned_scanned_uploads.rb"
  require_relative "jobs/scheduled/flag_quarantined_uploads.rb"

  register_reviewable_type ReviewableUpload

  replace_flags(settings: PostActionType.flag_settings, score_type_names: %i[malicious_file])

  add_to_serializer(:site, :clamav_unreacheable, false) do
    !!PluginStore.get(
      DiscourseAntivirus::ClamAV::PLUGIN_NAME,
      DiscourseAntivirus::ClamAV::UNAVAILABLE,
    )
  end

  add_to_serializer(:site, :include_clamav_unreacheable?, false) do
    SiteSetting.discourse_antivirus_enabled? && scope.is_staff?
  end

  on(:site_setting_changed) do |name, _, new_val|
    Jobs.enqueue(:fetch_antivirus_version) if name == :discourse_antivirus_enabled && new_val
  end

  on(:before_upload_creation) do |file, is_image, upload, validate|
    should_scan_file = !upload.for_export && (!is_image || SiteSetting.antivirus_live_scan_images)

    if validate && should_scan_file && upload.valid?
      antivirus = DiscourseAntivirus::ClamAV.instance

      response = antivirus.scan_file(file)
      is_positive = response[:found]

      upload.errors.add(:base, I18n.t("scan.virus_found")) if is_positive
    end
  end

  if defined?(::DiscoursePrometheus)
    require_relative "lib/discourse_antivirus/clamav_health_metric.rb"

    DiscoursePluginRegistry.register_global_collector(DiscourseAntivirus::ClamAVHealthMetric, self)
  end

  add_reviewable_score_link(:malicious_file, "plugin:discourse-antivirus")
end
