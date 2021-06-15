# frozen_string_literal: true

module DiscourseAntivirus
  class AntivirusController < Admin::AdminController
    requires_plugin 'discourse-antivirus'

    def index
      antivirus = DiscourseAntivirus::ClamAV.instance

      render json: DiscourseAntivirus::BackgroundScan.new(antivirus).stats
    end
  end
end
