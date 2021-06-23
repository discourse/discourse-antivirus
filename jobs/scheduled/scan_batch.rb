# frozen_string_literal: true

module Jobs
  class ScanBatch < ::Jobs::Scheduled
    every 15.minutes

    def execute(_args)
      return unless SiteSetting.discourse_antivirus_enabled?

      antivirus = DiscourseAntivirus::ClamAV.instance
      return unless antivirus.accepting_connections?

      DiscourseAntivirus::BackgroundScan.new(antivirus).scan_batch
    end
  end
end
