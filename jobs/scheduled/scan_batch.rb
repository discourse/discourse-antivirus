# frozen_string_literal: true

module Jobs
  class ScanBatch < ::Jobs::Scheduled
    every 15.minutes

    def execute(_args)
      return unless SiteSetting.discourse_antivirus_enabled?
      return unless DiscourseAntivirus::ClamAVServicesPool.correctly_configured?

      scanner = DiscourseAntivirus::BackgroundScan.new(DiscourseAntivirus::ClamAV.instance)
      scanner.scan_batch
    end
  end
end
