# frozen_string_literal: true

module DiscourseAntivirus
  class BackgroundScan
    def initialize(antivirus)
      @antivirus = antivirus
    end

    def scan(upload)
      scanned_upload = ScannedUpload.find_or_initialize_by(upload: upload, quarantined: false)
      scanned_upload.last_scanned_at = Time.now.utc
      scan_result = @antivirus.scan_upload(upload)

      if scan_result[:found]
        scanned_upload.move_to_quarantine!(scan_result[:message])
      else
        scanned_upload.save!
      end

      scanned_upload
    end
  end
end
