# frozen_string_literal: true

require "rails_helper"

describe ScannedUpload do
  let(:post) { Fabricate(:post) }
  let(:upload) { Fabricate(:upload, posts: [post]) }

  let(:scanned_upload) { described_class.new(upload: upload) }
  let(:database_version) { 25_852 }
  let(:scan_message) { "1: stream: Win.Test.EICAR_HDB-1 FOUND" }

  before { SiteSetting.flag_malicious_uploads = true }

  describe "#update_using!" do
    let(:result) { { error: false, found: true, message: scan_message } }

    it "sets the scan_message if there was no error" do
      scanned_upload.update_using!(result, database_version)

      reviewable_upload = ReviewableUpload.find_by(target: upload)

      expect(reviewable_upload).to be_present
      expect(scanned_upload.scan_result).to eq(scan_message)
      expect(scanned_upload.quarantined).to eq(true)
    end

    it "does not flag the upload if the flag_malicious_uploads setting is disabled" do
      SiteSetting.flag_malicious_uploads = false

      scanned_upload.update_using!(result, database_version)

      reviewable_upload = ReviewableUpload.find_by(target: upload)

      expect(reviewable_upload).to be_nil
    end
  end

  describe "#flag_upload" do
    before { scanned_upload.quarantined = true }

    it "removes the upload link and locks the post" do
      upload_link =
        "#{Upload.base62_sha1(upload.sha1)}#{upload.extension.present? ? ".#{upload.extension}" : ""}"
      post.raw = "[attachment.jpg|attachment](upload://#{upload_link})"

      scanned_upload.flag_upload(scan_message)

      qurantined_post = post.reload

      expect(qurantined_post.raw).to eq(I18n.t("scan.quarantined"))
      expect(qurantined_post.locked_by_id).to eq(Discourse.system_user.id)
    end

    it "creates a reviewable for the quarantined upload" do
      scanned_upload.flag_upload(scan_message)

      reviewable = ReviewableUpload.find_by(target: upload)

      expect(reviewable).to be_pending
      expect(reviewable.topic).to eq(upload.posts.last.topic)
      expect(reviewable.target_created_by).to eq(upload.user)
      expect(reviewable.target).to eq(upload)
      expect(reviewable.payload["scan_message"]).to eq(scan_message)
    end
  end

  describe "#mark_as_scanned_with" do
    it "sets attributes" do
      scans = scanned_upload.scans
      upload.created_at = 1.day.ago

      scanned_upload.mark_as_scanned_with(scan_message, database_version)

      expect(scanned_upload.quarantined).to eq(false)
      expect(scanned_upload.virus_database_version_used).to eq(database_version)
      expect(scanned_upload.next_scan_at).to be_nil
      expect(scanned_upload.scans).to eq(scans + 1)
    end

    it "resets the next_scan_at if the upload is less than a week old" do
      upload.created_at = 1.day.ago
      scanned_upload.next_scan_at = 1.day.ago

      scanned_upload.mark_as_scanned_with(scan_message, database_version)

      expect(scanned_upload.next_scan_at).to be_nil
    end

    it "sets the next scan to one week from now after the first week" do
      upload.created_at = 1.week.ago
      scanned_upload.next_scan_at = nil

      scanned_upload.mark_as_scanned_with(scan_message, database_version)

      expect(scanned_upload.next_scan_at).to eq_time(1.week.from_now)
    end

    it "sets the next scan to x weeks in the future where x is the number of weeks since created" do
      upload.created_at = 2.weeks.ago
      scanned_upload.next_scan_at = 1.day.ago

      scanned_upload.mark_as_scanned_with(scan_message, database_version)

      expect(scanned_upload.next_scan_at).to eq_time(2.weeks.from_now)
    end
  end
end
