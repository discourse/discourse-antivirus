# frozen_string_literal: true

module DiscourseAntivirus
  class BackgroundScan
    def initialize(antivirus)
      @antivirus = antivirus
    end

    def self.stats
      scanned_upload_stats = DB.query_single(<<~SQL
        SELECT 
          SUM(scans),
          SUM(CASE WHEN last_scanned_at >= NOW() - INTERVAL '24 HOURS' THEN 1 ELSE 0 END),
          SUM(CASE WHEN quarantined THEN 1 ELSE 0 END)
        FROM scanned_uploads
      SQL
      )

      {
        scans: scanned_upload_stats[0] || 0,
        recently_scanned: scanned_upload_stats[1] || 0,
        quarantined: scanned_upload_stats[2] || 0,
        found: ReviewableUpload.count
       }
    end

    def scan_batch(batch_size: 1000, scanned_before:)
      scanned = 0

      Upload
        .where('uploads.id >= 1 AND uploads.user_id >= 1')
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
        scanned_upload.scans += 1

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
