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
          SUM(CASE WHEN scans > 0 AND updated_at >= NOW() - INTERVAL '24 HOURS' THEN 1 ELSE 0 END),
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

    def current_database_version
      @antivirus.versions.first[:database]
    end

    def scan_batch(batch_size: 1000)
      Upload
        .where('uploads.id >= 1 AND uploads.user_id >= 1')
        .joins('LEFT OUTER JOIN scanned_uploads su ON uploads.id = su.upload_id')
        .where('
          su.id IS NULL OR
          (NOT su.quarantined AND (
            (
              su.next_scan_at IS NULL AND su.virus_database_version_used < ?) OR
              su.next_scan_at < NOW()
            )
          )',
          current_database_version
        )
        .find_in_batches(batch_size: batch_size) { |uploads| scan(uploads) }
    end

    def scan(uploads)
      return if uploads.blank?

      @antivirus.scan_multiple_uploads(uploads) do |upload, result|
        scanned_upload = ScannedUpload.find_or_initialize_by(upload: upload)

        scanned_upload.update_using!(result, current_database_version)
      end
    end
  end
end
