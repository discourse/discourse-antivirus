# frozen_string_literal: true

module Jobs
  class RemoveOrphanedScannedUploads < Jobs::Scheduled
    every 1.hour

    def execute(_args)
      return unless SiteSetting.discourse_antivirus_enabled?

      ScannedUpload
        .joins("LEFT OUTER JOIN uploads u ON u.id = upload_id")
        .where(u: { id: nil })
        .delete_all
    end
  end
end
