# frozen_string_literal: true

class ProblemCheck::ClamavUnavailable < ProblemCheck
  self.priority = "high"

  def call
    return no_problem if !SiteSetting.discourse_antivirus_enabled
    return no_problem if !clamav_unavailable?

    problem
  end

  private

  def clamav_unavailable?
    !!PluginStore.get(
      DiscourseAntivirus::ClamAv::PLUGIN_NAME,
      DiscourseAntivirus::ClamAv::UNAVAILABLE,
    )
  end
end
