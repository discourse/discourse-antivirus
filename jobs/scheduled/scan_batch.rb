# frozen_string_literal: true

module Jobs
  class ScanBatch < ::Jobs::Scheduled
    every 15.minutes

    def execute(_args)
      return unless SiteSetting.discourse_antivirus_enabled?

      pool = DiscourseAntivirus::ClamAVServicesPool.new
      return unless pool.accepting_connections?
      antivirus = DiscourseAntivirus::ClamAV.instance(sockets_pool: pool)

      DiscourseAntivirus::BackgroundScan.new(antivirus).scan_batch
    end
  end
end
