# frozen_string_literal: true

class ScannedUpload < ActiveRecord::Base
  belongs_to :upload

  def self.create_new!(upload)
    create!(upload: upload, next_scan_at: 10.minutes.from_now)
  end

  def update_using!(result, database_version)
    if result[:error]
      self.next_scan_at = 1.day.from_now
      self.last_scan_failed = true
      self.scan_result = result[:message]
    else
      mark_as_scanned_with(result[:message], database_version)
      self.quarantined = result[:found]
      flag_upload(result[:message]) if self.quarantined && SiteSetting.flag_malicious_uploads?
    end

    save!
  end

  def mark_as_scanned_with(message, database_version)
    self.scans += 1
    self.virus_database_version_used = database_version
    self.last_scan_failed = false
    self.scan_result = message

    upload_created_at = upload.created_at || Date.today
    week_number = upload_created_at.to_date.step(Date.today, 7).count

    if week_number > 1
      self.next_scan_at =
        self.next_scan_at.nil? ? 1.week.from_now : (week_number - 1).weeks.from_now
    else
      self.next_scan_at = nil
    end
  end

  def flag_upload(scan_message = self.scan_result)
    return if !self.quarantined || ReviewableUpload.exists?(target: upload)

    system_user = Discourse.system_user
    upload_link =
      "#{Upload.base62_sha1(upload.sha1)}#{upload.extension.present? ? ".#{upload.extension}" : ""}"
    original_post_raw_example = upload.posts.last&.raw

    self.class.transaction do
      uploaded_to =
        upload.posts.map do |post|
          quarantined_raw =
            post.raw.gsub(%r{!?\[(.*?)\]\(upload://#{upload_link}\)}, I18n.t("scan.quarantined"))
          post.update!(raw: quarantined_raw, locked_by_id: system_user.id)
          post.id
        end

      reviewable =
        ReviewableUpload.needs_review!(
          created_by: system_user,
          target: upload,
          reviewable_by_moderator: true,
          topic: upload.posts.last&.topic,
          payload: {
            scan_message: scan_message,
            original_filename: upload.original_filename,
            post_raw: original_post_raw_example,
            uploaded_by: upload.user.username,
            uploaded_to: uploaded_to,
          },
        )
      reviewable.update!(target_created_by: upload.user)
      reviewable.add_score(
        system_user,
        ReviewableScore.types[:malicious_file],
        created_at: reviewable.created_at,
        reason: "malicious_file",
        force_review: true,
      )

      SystemMessage.new(upload.user).create("malicious_file", filename: upload.original_filename)

      upload.posts.each do |post|
        post.rebake!(invalidate_oneboxes: true, invalidate_broken_images: true)
      end
    end
  end

  private

  def handle_scan_result(result)
    result[:found] ? move_to_quarantine!(result[:message]) : save!
  end
end
