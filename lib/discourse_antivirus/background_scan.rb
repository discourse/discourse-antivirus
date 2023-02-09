# frozen_string_literal: true

module DiscourseAntivirus
  class BackgroundScan
    def initialize(antivirus)
      @antivirus = antivirus
    end

    def stats
      scanned_upload_stats = DB.query_single(<<~SQL)
        SELECT
          SUM(scans),
          SUM(CASE WHEN scans > 0 AND updated_at >= NOW() - INTERVAL '24 HOURS' THEN 1 ELSE 0 END),
          SUM(CASE WHEN quarantined THEN 1 ELSE 0 END)
        FROM scanned_uploads
      SQL

      {
        versions: @antivirus.versions,
        background_scan_stats: {
          scans: scanned_upload_stats[0] || 0,
          recently_scanned: scanned_upload_stats[1] || 0,
          quarantined: scanned_upload_stats[2] || 0,
          found: ReviewableUpload.count,
        },
      }
    end

    def queue_batch(batch_size: 1000)
      Upload
        .distinct
        .where("uploads.id >= 1 AND uploads.user_id >= 1")
        .joins("LEFT OUTER JOIN scanned_uploads su ON uploads.id = su.upload_id")
        .joins("LEFT OUTER JOIN upload_references ur ON uploads.id = ur.upload_id")
        .joins("LEFT OUTER JOIN posts p ON ur.target_id = p.id")
        .where("su.id IS NULL")
        .where(
          "ur.id IS NULL OR ur.target_type <> 'Post' OR (ur.target_type = 'Post' AND p.user_id >= 1)",
        )
        .limit(batch_size)
        .find_each { |upload| ScannedUpload.create_new!(upload) }
    end

    def scan_batch(batch_size: 1000)
      ScannedUpload
        .includes(:upload)
        .where(
          "
          (NOT quarantined AND
            (
              (next_scan_at IS NULL AND virus_database_version_used < ?) OR
              next_scan_at < NOW()
            )
          )",
          current_database_version,
        )
        .limit(batch_size)
        .find_in_batches { |scanned_uploads| scan(scanned_uploads) }
    end

    def scan(scanned_uploads)
      return if scanned_uploads.blank?

      scanned_uploads.each do |scanned_upload|
        result = @antivirus.scan_upload(scanned_upload.upload)

        scanned_upload.update_using!(result, current_database_version)
      end
    end

    private

    def current_database_version
      @antivirus.versions.first[:database]
    end
  end
end
