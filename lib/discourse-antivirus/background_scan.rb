# frozen_string_literal: true

module DiscourseAntivirus
  class BackgroundScan
    def initialize(antivirus)
      @antivirus = antivirus
    end

    def scan_batch(batch_size: 1000, scanned_before:)
      scanned = 0

      Upload
        .where('uploads.id >= 1')
        .joins('LEFT OUTER JOIN scanned_uploads su ON uploads.id = su.upload_id')
        .where('su.id IS NULL OR (NOT su.quarantined AND su.last_scanned_at <= ?)', scanned_before)
        .limit(batch_size)
        .find_in_batches do |uploads|
          scanned += uploads.size
          scan(uploads)
        end

      scanned
    end

    def scan(uploads)
      return if uploads.blank?
      scan_results = @antivirus.scan_multiple_uploads(uploads)

      scan_results.each do |result|
        scanned_upload = ScannedUpload.find_or_initialize_by(upload: result[:upload])
        scanned_upload.last_scanned_at = Time.zone.now

        if result[:found]
          scanned_upload.move_to_quarantine!(result[:message])
        else
          scanned_upload.quarantined = false
          scanned_upload.save!
        end
      end
    end
  end
end
