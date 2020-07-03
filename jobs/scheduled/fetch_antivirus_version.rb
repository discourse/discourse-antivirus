# frozen_string_literal: true

module Jobs
  class FetchAntivirusVersion < ::Jobs::Scheduled
    every 6.hours

    def execute(_args)
      return unless SiteSetting.discourse_antivirus_enabled?

      DiscourseAntivirus::ClamAV.instance.update_version
    end
  end
end
