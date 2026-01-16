# frozen_string_literal: true

describe Jobs::RemoveOrphanedScannedUploads do
  subject(:execute) { described_class.new.execute({}) }

  let(:upload) { Fabricate(:upload) }
  let!(:scanned_upload) { ScannedUpload.create_new!(upload) }

  before { SiteSetting.discourse_antivirus_enabled = true }

  context "when the upload still exists" do
    it "does nothing" do
      expect { execute }.not_to change { scanned_upload.reload }
    end
  end

  context "when the upload is gone" do
    before { upload.destroy! }

    it "deletes the scanned upload" do
      expect { execute }.to change { ScannedUpload.where(id: scanned_upload.id).count }.by(-1)
    end
  end
end
