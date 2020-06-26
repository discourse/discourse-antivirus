# frozen_string_literal: true

module Jobs
  class ScanBatch < ::Jobs::Scheduled
    every 5.minutes

    def execute(_args)
      return unless SiteSetting.discourse_antivirus_enabled?
      scanner = DiscourseAntivirus::BackgroundScan.new(DiscourseAntivirus::ClamAV.instance)
      next_scan_at = SiteSetting.antivirus_next_scan_at

      if next_scan_at.blank?
        next_scan_at = Time.zone.now
        SiteSetting.antivirus_next_scan_at = next_scan_at
      end

      scanned = scanner.scan_batch(scanned_before: next_scan_at)

      SiteSetting.antivirus_next_scan_at = 12.hours.from_now if scanned.zero?
    end
  end
end
