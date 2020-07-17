# frozen_string_literal: true

require 'rails_helper'

describe ScannedUpload do
  let(:post) { Fabricate(:post) }
  let(:upload) { Fabricate(:upload, posts: [post]) }

  let(:scanned_upload) { described_class.new(upload: upload) }
  let(:scan_message) { "1: stream: Win.Test.EICAR_HDB-1 FOUND\0" }

  describe '#move_to_quarantine!' do
    it 'removes the upload link and locks the post' do
      upload_link = "#{Upload.base62_sha1(upload.sha1)}#{upload.extension.present? ? ".#{upload.extension}" : ""}"
      post.raw = "[attachment.jpg|attachment](upload://#{upload_link})"

      scanned_upload.move_to_quarantine!(scan_message)

      qurantined_post = post.reload

      expect(qurantined_post.raw).to eq(I18n.t("scan.quarantined"))
      expect(qurantined_post.locked_by_id).to eq(Discourse.system_user.id)
    end

    it 'creates a reviewable for the quarantined upload' do
      scanned_upload.move_to_quarantine!(scan_message)

      reviewable = ReviewableUpload.find_by(target: upload)

      expect(reviewable.status).to eq(Reviewable.statuses[:pending])
      expect(reviewable.topic).to eq(upload.posts.last.topic)
      expect(reviewable.target_created_by).to eq(upload.user)
      expect(reviewable.target).to eq(upload)
      expect(reviewable.payload['scan_message']).to eq(scan_message)
    end
  end

  describe '#mark_as_scanned_with' do
    let(:database_version) { 25852 }

    it 'sets attributes' do
      scans = scanned_upload.scans
      upload.created_at = 1.day.ago

      scanned_upload.mark_as_scanned_with(database_version)

      expect(scanned_upload.quarantined).to eq(false)
      expect(scanned_upload.virus_database_version_used).to eq(database_version)
      expect(scanned_upload.next_scan_at).to be_nil
      expect(scanned_upload.scans).to eq(scans + 1)
    end

    it 'resets the next_scan_at if the upload is less than a week old' do
      upload.created_at = 1.day.ago
      scanned_upload.next_scan_at = 1.day.ago

      scanned_upload.mark_as_scanned_with(database_version)

      expect(scanned_upload.next_scan_at).to be_nil
    end

    it 'sets the next scan to one week from now after the first week' do
      upload.created_at = 1.week.ago
      scanned_upload.next_scan_at = nil

      scanned_upload.mark_as_scanned_with(database_version)

      expect(scanned_upload.next_scan_at).to eq_time(1.week.from_now)
    end

    it 'sets the next scan to x weeks in the future where x is the number of weeks since created' do
      upload.created_at = 2.weeks.ago
      scanned_upload.next_scan_at = 1.day.ago

      scanned_upload.mark_as_scanned_with(database_version)

      expect(scanned_upload.next_scan_at).to eq_time(2.weeks.from_now)
    end
  end
end
