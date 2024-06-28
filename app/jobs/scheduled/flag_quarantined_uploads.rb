# frozen_string_literal: true

module Jobs
  class FlagQuarantinedUploads < ::Jobs::Scheduled
    every 3.hours

    def execute(_args)
      return unless SiteSetting.flag_malicious_uploads?

      ScannedUpload
        .where(quarantined: true)
        .joins(
          "LEFT OUTER JOIN reviewables r ON r.target_id = scanned_uploads.upload_id AND r.type = 'ReviewableUpload'",
        )
        .where(r: { id: nil })
        .find_each { |su| su.flag_upload }
    end
  end
end
