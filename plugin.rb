# frozen_string_literal: true

# name: discourse-antivirus
# about: Scan uploads
# version: 0.1
# authors: romanrizzi
# url: https://github.com/discourse/discourse-antivirus

gem 'dns-sd', '0.1.3'

enabled_site_setting :discourse_antivirus_enabled
register_asset 'stylesheets/reviewable-upload.scss'

# TODO: Remove after 2.6 gets released
register_asset 'stylesheets/hide-malicious-file-flag.scss'

PLUGIN_NAME ||= 'DiscourseAntivirus'

load File.expand_path('lib/discourse_antivirus/engine.rb', __dir__)
load File.expand_path('lib/validators/enable_discourse_antivirus_validator.rb', __dir__)

add_admin_route 'antivirus.title', 'antivirus'

after_initialize do
  require_dependency File.expand_path('../app/controllers/discourse_antivirus/antivirus_controller.rb', __FILE__)
  require_dependency File.expand_path('../lib/discourse_antivirus/clamav_services_pool.rb', __FILE__)
  require_dependency File.expand_path('../lib/discourse_antivirus/clamav.rb', __FILE__)
  require_dependency File.expand_path('../lib/discourse_antivirus/background_scan.rb', __FILE__)
  require_dependency File.expand_path('../models/scanned_upload.rb', __FILE__)
  require_dependency File.expand_path('../models/reviewable_upload.rb', __FILE__)
  require_dependency File.expand_path('../serializers/reviewable_upload_serializer.rb', __FILE__)
  require_dependency File.expand_path('../jobs/scheduled/scan_batch.rb', __FILE__)
  require_dependency File.expand_path('../jobs/scheduled/create_scanned_uploads.rb', __FILE__)
  require_dependency File.expand_path('../jobs/scheduled/fetch_antivirus_version.rb', __FILE__)
  require_dependency File.expand_path('../jobs/scheduled/remove_orphaned_scanned_uploads.rb', __FILE__)
  require_dependency File.expand_path('../jobs/scheduled/flag_quarantined_uploads.rb', __FILE__)

  register_reviewable_type ReviewableUpload

  # TODO: Remove after 2.6 gets released
  if ReviewableScore.respond_to?(:add_new_types)
    replace_flags(settings: PostActionType.flag_settings, score_type_names: %i[malicious_file])
  else
    replace_flags(settings: PostActionType.flag_settings) do |settings, next_flag_id|
      settings.add(
        next_flag_id,
        :malicious_file,
        topic_type: true,
        notify_type: true
      )
    end
  end

  on(:site_setting_changed) do |name, _, new_val|
    if name == :discourse_antivirus_enabled && new_val
      Jobs.enqueue(:fetch_antivirus_version)
    end
  end

  on(:before_upload_creation) do |file, is_image, upload, validate|
    should_scan_file = !upload.for_export && (!is_image || SiteSetting.antivirus_live_scan_images)

    if validate && should_scan_file && upload.valid?
      is_positive = DiscourseAntivirus::ClamAV.instance.scan_file(file)[:found]

      upload.errors.add(:base, I18n.t('scan.virus_found')) if is_positive
    end
  end
end
