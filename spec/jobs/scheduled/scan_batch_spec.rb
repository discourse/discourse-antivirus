# frozen_string_literal: true

require 'rails_helper'

describe Jobs::ScanBatch do
  it 'schedules the next scan when there are no uploads left to scan' do
    SiteSetting.discourse_antivirus_enabled = true
    DiscourseAntivirus::ClamAV.stubs(:instance).returns(nil)
    DiscourseAntivirus::BackgroundScan.any_instance.stubs(:scan_batch).returns(0)
    SiteSetting.antivirus_next_scan_at = ''

    subject.execute({})

    expect(SiteSetting.antivirus_next_scan_at).to be_present
  end
end
