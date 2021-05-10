# frozen_string_literal: true

require_dependency 'reviewable'

class ReviewableUpload < Reviewable
  def build_actions(actions, guardian, _args)
    return [] unless pending?

    reject = actions.add_bundle(
      'reject_upload',
      icon: 'thumbs-up',
      label: 'js.antivirus.remove_upload.title'
    )

    build_action(actions, :remove_file, bundle: reject, icon: 'thumbs-up')
    build_action(actions, :remove_file_and_delete_posts, bundle: reject, icon: 'trash-alt')

    if target_created_by && guardian.can_delete_user?(target_created_by)
      build_action(
        actions,
        :remove_file_and_delete_user,
        bundle: reject,
        icon: 'ban',
        button_class: 'btn-danger',
        confirm: true
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
      context: I18n.t('antivirus.delete_reason', performed_by: performed_by.username),
      delete_posts: true
    }

    base.tap do |b|
      b.merge!(block_email: true, block_ip: true) if Rails.env.production?
    end
  end

  def post; end

  def successful_transition(to_state, update_flag_status)
    create_result(:success, to_state)  do |result|
      result.update_flag_stats = { status: update_flag_status, user_ids: [created_by_id] }
    end
  end

  def build_action(actions, id, icon:, bundle: nil, confirm: false, button_class: nil)
    actions.add(id, bundle: bundle) do |action|
      action.icon = icon
      action.label = "js.antivirus.#{id}"
      action.confirm_message = 'js.antivirus.reviewable_delete_prompt' if confirm
      action.button_class = button_class
    end
  end
end
