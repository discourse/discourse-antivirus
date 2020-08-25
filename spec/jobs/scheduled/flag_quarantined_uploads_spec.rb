# frozen_string_literal: true

require 'rails_helper'

describe Jobs::FlagQuarantinedUploads do
  describe '#execute' do
    let(:scan_message) { "Win.Test.EICAR_HDB-1 FOUND" }
    let(:upload) { Fabricate(:upload) }

    before do
      SiteSetting.flag_malicious_uploads = true
      @scanned_upload = ScannedUpload.create!(upload: upload, quarantined: true, scan_result: scan_message)
    end

    it 'flags the upload if it was previously quarantined' do
      subject.execute({})

      reviewable_upload = ReviewableUpload.find_by(target: upload)

      expect(reviewable_upload).to be_present
      expect(reviewable_upload.payload["scan_message"]).to eq(scan_message)
    end

    it 'does nothing if the flag_malicious_uploads flag is disabled' do
      SiteSetting.flag_malicious_uploads = false

      subject.execute({})
      reviewable_upload = ReviewableUpload.find_by(target: upload)

      expect(reviewable_upload).to be_nil
    end

    it 'does nothing if a reviewable already exists' do
      @scanned_upload.flag_upload

      subject.execute({})

      reviewable_upload = ReviewableUpload.find_by(target: upload)
      scores = reviewable_upload.reviewable_scores

      expect(scores.size).to eq(1)
    end

    it 'does nothing if the scanned upload is not quarantined' do
      @scanned_upload.update!(quarantined: false)

      subject.execute({})
      reviewable_upload = ReviewableUpload.find_by(target: upload)

      expect(reviewable_upload).to be_nil
    end
  end
end
