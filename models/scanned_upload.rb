# frozen_string_literal: true

class ScannedUpload < ActiveRecord::Base
  belongs_to :upload

  def move_to_quarantine!(scan_message)
    return if quarantined

    system_user = Discourse.system_user
    upload_link = "#{Upload.base62_sha1(upload.sha1)}#{upload.extension.present? ? ".#{upload.extension}" : ""}"
    original_post_cooked_example = upload.posts.last&.cooked

    self.class.transaction do
      self.quarantined = true

      uploaded_to = upload.posts.map do |post|
        quarantined_raw = post.raw.gsub(/!?\[(.*?)\]\(upload:\/\/#{upload_link}\)/, I18n.t("scan.quarantined"))
        post.update!(raw: quarantined_raw, locked_by_id: system_user.id)
        post.id
      end

      reviewable = ReviewableUpload.needs_review!(
        created_by: system_user, target: upload, reviewable_by_moderator: true,
        payload: {
          scan_message: scan_message,
          original_filename: upload.original_filename,
          post_cooked: original_post_cooked_example,
          uploaded_by: upload.user.username,
          uploaded_to: uploaded_to
        }
      )

      reviewable.add_score(
        system_user, PostActionType.types[:malicious_file],
        created_at: reviewable.created_at, reason: 'malicious_file'
      )

      save!
    end

    SystemMessage.new(upload.user).create('malicious_file', filename: upload.original_filename)

    upload.posts.each do |post|
      post.rebake!(invalidate_oneboxes: true, invalidate_broken_images: true)
    end
  end
end
