# frozen_string_literal: true

require "rails_helper"

describe Jobs::RemoveOrphanedScannedUploads do
  let(:upload) { Fabricate(:upload) }

  before do
    SiteSetting.discourse_antivirus_enabled = true
    @scanned_upload = ScannedUpload.create_new!(upload)
  end

  it "does nothing if the upload still exists" do
    subject.execute({})

    expect(@scanned_upload.reload).to be_present
  end

  it "deletes the scanned upload if the upload is gone" do
    upload.destroy!

    subject.execute({})
    orphaned_upload = ScannedUpload.find_by(id: @scanned_upload.id)

    expect(orphaned_upload).to be_nil
  end
end
