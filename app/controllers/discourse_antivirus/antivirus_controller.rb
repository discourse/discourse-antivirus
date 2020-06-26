# frozen_string_literal: true

module DiscourseAntivirus
  class AntivirusController < Admin::AdminController
    requires_plugin 'discourse-antivirus'

    def index
      render json: {
        antivirus: DiscourseAntivirus::ClamAV.instance.version,
        background_scan_stats: DiscourseAntivirus::BackgroundScan.stats
      }
    end
  end
end
