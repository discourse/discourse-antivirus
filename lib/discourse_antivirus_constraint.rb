# frozen_string_literal: true
class DiscourseAntivirusConstraint
  def matches?(request)
    SiteSetting.discourse_antivirus_enabled
  end
end
