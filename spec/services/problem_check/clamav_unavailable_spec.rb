# frozen_string_literal: true

RSpec.describe ProblemCheck::ClamavUnavailable do
  subject(:check) { described_class.new }

  before { SiteSetting.discourse_antivirus_enabled = true }

  def set_clamav_availability(available)
    PluginStore.set(
      DiscourseAntivirus::ClamAv::PLUGIN_NAME,
      DiscourseAntivirus::ClamAv::UNAVAILABLE,
      !available,
    )
  end

  it "reports a problem when ClamAV is unavailable" do
    set_clamav_availability(false)

    expect(check).to have_a_problem.with_priority("high").with_message(
      "We cannot establish a connection with the antivirus software. File scanning will be temporarily disabled.",
    )
  end

  it "has no problem when ClamAV is available" do
    set_clamav_availability(true)

    expect(check).to be_chill_about_it
  end

  it "has no problem when the plugin is disabled" do
    SiteSetting.discourse_antivirus_enabled = false
    set_clamav_availability(false)

    expect(check).to be_chill_about_it
  end
end
