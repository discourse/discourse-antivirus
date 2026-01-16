# frozen_string_literal: true

describe Jobs::FlagQuarantinedUploads do
  describe "#execute" do
    subject(:execute) { described_class.new.execute({}) }

    let(:scan_message) { "Win.Test.EICAR_HDB-1 FOUND" }
    let(:upload) { Fabricate(:upload) }
    let(:reviewable_upload) { ReviewableUpload.find_by(target: upload) }
    let!(:scanned_upload) do
      ScannedUpload.create!(upload: upload, quarantined: true, scan_result: scan_message)
    end

    before { SiteSetting.flag_malicious_uploads = true }

    it "flags the upload if it was previously quarantined" do
      execute
      expect(reviewable_upload.payload["scan_message"]).to eq(scan_message)
    end

    context "when the flag_malicious_uploads flag is disabled" do
      before { SiteSetting.flag_malicious_uploads = false }

      it "does nothing" do
        execute
        expect(reviewable_upload).to be_nil
      end
    end

    context "when a reviewable already exists" do
      before { scanned_upload.flag_upload }

      it "does nothing" do
        execute

        expect(reviewable_upload.reviewable_scores.size).to eq(1)
      end
    end

    context "when the scanned upload is not quarantined" do
      before { scanned_upload.update!(quarantined: false) }

      it "does nothing" do
        execute

        expect(reviewable_upload).to be_nil
      end
    end
  end
end
