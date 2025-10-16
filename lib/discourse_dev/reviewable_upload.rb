# frozen_string_literal: true

module DiscourseDev
  class ReviewableUpload < Reviewable
    def populate!
      if !GlobalSetting.respond_to?(:clamav_hostname)
        def GlobalSetting.clamav_hostname
          ""
        end
      end
      if !GlobalSetting.respond_to?(:clamav_port)
        def GlobalSetting.clamav_port
          ""
        end
      end
      user = @users.sample
      post = @posts.sample

      file = File.new("#{Rails.root}/spec/fixtures/images/logo.jpg")
      upload = UploadCreator.new(file, "logo.jpg").create_for(user.id)
      post.uploads << upload if upload.upload_references.empty?
      reviewable =
        ::ReviewableUpload.needs_review!(
          created_by: Discourse.system_user,
          target: upload,
          target_created_by: user,
          reviewable_by_moderator: true,
          topic: post.topic,
          payload: {
            scan_message: "scan message",
            original_filename: upload.original_filename,
            post_raw: post.raw,
            uploaded_by: upload.user.username,
            uploaded_to: [post.id],
          },
        )
      reviewable.add_score(
        Discourse.system_user,
        ReviewableScore.types[:malicious_file],
        created_at: reviewable.created_at,
        reason: "malicious_file",
        force_review: true,
      )
    end
  end
end
