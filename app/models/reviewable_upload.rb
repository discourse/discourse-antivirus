# frozen_string_literal: true

require_dependency "reviewable"

class ReviewableUpload < Reviewable
  def build_actions(actions, guardian, _args)
    return [] unless pending?

    reject =
      actions.add_bundle(
        "reject_upload",
        icon: "thumbs-up",
        label: "js.antivirus.remove_upload.title",
      )

    build_action(actions, :remove_file, bundle: reject, icon: "thumbs-up")
    build_action(actions, :remove_file_and_delete_posts, bundle: reject, icon: "trash-alt")

    if target_created_by && guardian.can_delete_user?(target_created_by)
      build_action(
        actions,
        :remove_file_and_delete_user,
        bundle: reject,
        icon: "ban",
        button_class: "btn-danger",
        confirm: true,
      )
    end
  end

  def perform_remove_file(performed_by, _args)
    remove_upload!

    successful_transition :deleted, :agreed
  end

  def perform_remove_file_and_delete_posts(performed_by, _args)
    posts.each { |post| PostDestroyer.new(performed_by, post, defer_flags: true).destroy }
    remove_upload!

    successful_transition :deleted, :agreed
  end

  def perform_remove_file_and_delete_user(performed_by, _args)
    if target_created_by && Guardian.new(performed_by).can_delete_user?(target_created_by)
      UserDestroyer.new(performed_by).destroy(target_created_by, user_deletion_opts(performed_by))
    end

    remove_upload!

    successful_transition :deleted, :agreed
  end

  private

  def remove_upload!
    ScannedUpload.where(upload_id: target_id).delete_all
    target.destroy! if target
  end

  def posts
    @posts ||= Post.where(id: payload["uploaded_to"])
  end

  def user_deletion_opts(performed_by)
    base = {
      context: I18n.t("antivirus.delete_reason", performed_by: performed_by.username),
      delete_posts: true,
    }

    base.tap { |b| b.merge!(block_email: true, block_ip: true) if Rails.env.production? }
  end

  def post
  end

  def successful_transition(to_state, update_flag_status)
    create_result(:success, to_state) do |result|
      result.update_flag_stats = { status: update_flag_status, user_ids: [created_by_id] }
    end
  end

  def build_action(actions, id, icon:, bundle: nil, confirm: false, button_class: nil)
    actions.add(id, bundle: bundle) do |action|
      action.icon = icon
      action.label = "js.antivirus.#{id}"
      action.confirm_message = "js.antivirus.reviewable_delete_prompt" if confirm
      action.button_class = button_class
    end
  end
end

# == Schema Information
#
# Table name: reviewables
#
#  id                      :bigint           not null, primary key
#  type                    :string           not null
#  status                  :integer          default("pending"), not null
#  created_by_id           :integer          not null
#  reviewable_by_moderator :boolean          default(FALSE), not null
#  category_id             :integer
#  topic_id                :integer
#  score                   :float            default(0.0), not null
#  potential_spam          :boolean          default(FALSE), not null
#  target_id               :integer
#  target_type             :string
#  target_created_by_id    :integer
#  payload                 :json
#  version                 :integer          default(0), not null
#  latest_score            :datetime
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  force_review            :boolean          default(FALSE), not null
#  reject_reason           :text
#  potentially_illegal     :boolean          default(FALSE)
#  type_source             :string           default("unknown"), not null
#
# Indexes
#
#  idx_reviewables_score_desc_created_at_desc                  (score,created_at)
#  index_reviewables_on_reviewable_by_group_id                 (reviewable_by_group_id)
#  index_reviewables_on_status_and_created_at                  (status,created_at)
#  index_reviewables_on_status_and_score                       (status,score)
#  index_reviewables_on_status_and_type                        (status,type)
#  index_reviewables_on_target_id_where_post_type_eq_post      (target_id) WHERE ((target_type)::text = 'Post'::text)
#  index_reviewables_on_topic_id_and_status_and_created_by_id  (topic_id,status,created_by_id)
#  index_reviewables_on_type_and_target_id                     (type,target_id) UNIQUE
#
