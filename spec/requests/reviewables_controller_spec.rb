# frozen_string_literal: true

RSpec.describe ReviewablesController do
  fab!(:admin)
  fab!(:moderator)
  fab!(:uploader, :user)
  fab!(:participant, :user)

  before { enable_current_plugin }

  describe "#show" do
    it "hides PM raw from non-participant moderators", :aggregate_failures do
      upload = Fabricate(:upload, user: uploader)
      upload_link =
        "#{Upload.base62_sha1(upload.sha1)}#{upload.extension.present? ? ".#{upload.extension}" : ""}"
      private_message_raw = "Private message secret [file](upload://#{upload_link})"
      private_message_topic =
        Fabricate(:private_message_topic, user: uploader, recipient: participant)
      post =
        Fabricate(:post, topic: private_message_topic, user: uploader, raw: private_message_raw)
      upload.update!(posts: [post])

      scanned_upload = ScannedUpload.create!(upload: upload, quarantined: true)
      scanned_upload.flag_upload("Eicar-Test-Signature FOUND")
      reviewable = ReviewableUpload.find_by!(target: upload)

      sign_in(moderator)
      get "/review/#{reviewable.id}.json"

      expect(response.status).to eq(404)
      expect(response.body).not_to include(private_message_raw)

      sign_in(admin)
      get "/review/#{reviewable.id}.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["reviewable"]["payload"]["post_raw"]).to eq(private_message_raw)
    end

    it "hides whisper raw from non-whispering reviewers", :aggregate_failures do
      whisperers_group = Fabricate(:group)
      SiteSetting.whispers_allowed_groups = whisperers_group.id.to_s
      SiteSetting.enable_category_group_moderation = true

      category = Fabricate(:category)
      category_moderator = Fabricate(:user)
      category_moderation_group = Fabricate(:group)
      category_moderation_group.add(category_moderator)
      CategoryModerationGroup.create!(
        category_id: category.id,
        group_id: category_moderation_group.id,
      )

      upload = Fabricate(:upload, user: uploader)
      upload_link =
        "#{Upload.base62_sha1(upload.sha1)}#{upload.extension.present? ? ".#{upload.extension}" : ""}"
      whisper_raw = "Private staff note [file](upload://#{upload_link})"
      topic = Fabricate(:topic, category: category)
      post =
        Fabricate(
          :post,
          topic: topic,
          user: uploader,
          raw: whisper_raw,
          post_type: Post.types[:whisper],
        )
      upload.update!(posts: [post])

      scanned_upload = ScannedUpload.create!(upload: upload, quarantined: true)
      scanned_upload.flag_upload("Eicar-Test-Signature FOUND")
      reviewable = ReviewableUpload.find_by!(target: upload)

      [[moderator, 404], [category_moderator, 403]].each do |reviewer, expected_status|
        sign_in(reviewer)
        get "/review/#{reviewable.id}.json"

        expect(response.status).to eq(expected_status)
        expect(response.body).not_to include(whisper_raw)
      end
    end
  end
end
