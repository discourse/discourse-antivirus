# frozen_string_literal: true

module Jobs
  class CreateScannedUploads < ::Jobs::Scheduled
    every 10.minutes

    def execute(_args)
      return unless SiteSetting.discourse_antivirus_enabled?

      scanner = DiscourseAntivirus::BackgroundScan.new(DiscourseAntivirus::ClamAV.instance)
      scanner.queue_batch
    end
  end
end
