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
  end
end
