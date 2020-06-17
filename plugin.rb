# frozen_string_literal: true

# name: discourse-antivirus
# about: Scan uploads
# version: 0.1
# authors: romanrizzi
# url: https://github.com/romanrizzi

enabled_site_setting :discourse_antivirus_enabled
register_asset 'stylesheets/reviewable-upload.scss'

PLUGIN_NAME ||= 'DiscourseAntivirus'

load File.expand_path('lib/discourse-antivirus/engine.rb', __dir__)

after_initialize do
  require_dependency File.expand_path('../lib/discourse-antivirus/clamav.rb', __FILE__)
  require_dependency File.expand_path('../lib/discourse-antivirus/background_scan.rb', __FILE__)
  require_dependency File.expand_path('../models/scanned_upload.rb', __FILE__)
  require_dependency File.expand_path('../models/reviewable_upload.rb', __FILE__)
  require_dependency File.expand_path('../serializers/reviewable_upload_serializer.rb', __FILE__)

  register_reviewable_type ReviewableUpload

  replace_flags(settings: PostActionType.flag_settings) do |settings, next_flag_id|
    settings.add(
      next_flag_id,
      :malicious_file,
      topic_type: true,
      notify_type: true
    )
  end

  on(:before_upload_creation) do |file, is_image|
    should_scan_file = !is_image || SiteSetting.antivirus_live_scan_images

    if should_scan_file && DiscourseAntivirus::ClamAV.instance.scan_file(file)[:found]
      raise DiscourseAntivirus::ClamAV::VIRUS_FOUND, I18n.t('scan.virus_found')
    end
  end
end
