# frozen_string_literal: true

require_dependency 'reviewable'

class ReviewableUpload < Reviewable
  def build_actions(actions, guardian, _args)
    []
  end

  private

  def build_action(actions, id, icon:, bundle: nil, confirm: false, button_class: nil)
    actions.add(id, bundle: bundle) do |action|
      action.icon = icon
      action.label = "js.antivirus.#{id}"
      action.confirm_message = 'js.antivirus.reviewable_delete_prompt' if confirm
      action.button_class = button_class
    end
  end
end
