# frozen_string_literal: true

require 'rails_helper'

describe ReviewableUpload do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:upload) { Fabricate(:upload) }
  let(:reviewable) do
    ReviewableUpload.needs_review!(
      target: upload, created_by: Discourse.system_user, payload: { uploaded_to: [upload.post_ids] }
    )
  end

  describe 'performing actions' do
    describe '#perform_remove_file' do
      it 'removes the upload' do
        reviewable.perform admin, :remove_file

        reviewable.reload

        assert_upload_destroyed(reviewable)
      end

      it 'removes the upload and delete the posts where it was uploaded' do
        post = Fabricate(:post)
        upload.update(posts: [post])

        reviewable.perform admin, :remove_file_and_delete_posts
        reviewable.reload

        assert_upload_destroyed(reviewable)
        expect(post.reload.deleted_at).to be_present
      end

      it 'removes the upload and deletes the user' do
        user = Fabricate(:user)
        upload.update(user: user)

        reviewable.perform admin, :remove_file_and_delete_user
        reviewable.reload
        user = User.find_by(id: user.id)

        assert_upload_destroyed(reviewable)
        expect(user).to be_nil
      end

      it 'fails to perform the action if the user cannot be deleted' do
        user = Fabricate(:admin)
        upload.update(user: user)

        expect { reviewable.perform admin, :remove_file_and_delete_user }.to raise_error(Reviewable::InvalidAction)
      end

      def assert_upload_destroyed(reviewable)
        expect(reviewable.target).to be_nil
        expect(reviewable.status).to eq(Reviewable.statuses[:deleted])
      end
    end
  end
end
