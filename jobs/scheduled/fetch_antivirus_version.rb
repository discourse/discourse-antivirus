# frozen_string_literal: true

module Jobs
  class FetchAntivirusVersion < ::Jobs::Scheduled
    every 6.hours

    def execute(_args)
      return unless SiteSetting.discourse_antivirus_enabled?
      return if SiteSetting.antivirus_srv_record.blank?

      DiscourseAntivirus::ClamAV.instance.update_versions
    end
  end
end
