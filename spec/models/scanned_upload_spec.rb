# frozen_string_literal: true

require 'rails_helper'

describe ScannedUpload do
  let(:post) { Fabricate(:post) }
  let(:upload) { Fabricate(:upload, posts: [post]) }

  let(:scanned_upload) { described_class.new(upload: upload) }
  let(:scan_message) { "1: stream: Win.Test.EICAR_HDB-1 FOUND\0" }

  describe '#move_to_quarantine!' do
    it 'xxxxx' do
      upload_link = "#{Upload.base62_sha1(upload.sha1)}#{upload.extension.present? ? ".#{upload.extension}" : ""}"
      post.raw = "[attachment.jpg|attachment](upload://#{upload_link})"

      scanned_upload.move_to_quarantine!(scan_message)

      qurantined_post = post.reload

      expect(qurantined_post.raw).to eq(I18n.t("scan.quarantined"))
      expect(qurantined_post.locked_by_id).to eq(Discourse.system_user.id)
    end

    it 'sxsxsxs' do
      scanned_upload.move_to_quarantine!(scan_message)

      reviewable = ReviewableUpload.find_by(target: upload)

      expect(reviewable.status).to eq(Reviewable.statuses[:pending])
      expect(reviewable.target).to eq(upload)
      expect(reviewable.payload['scan_message']).to eq(scan_message)
    end
  end
end
