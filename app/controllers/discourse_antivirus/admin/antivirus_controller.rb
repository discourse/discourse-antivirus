# frozen_string_literal: true

module DiscourseAntivirus
  module Admin
    class AntivirusController < ::Admin::AdminController
      requires_plugin ::DiscourseAntivirus::PLUGIN_NAME

      def index
        antivirus = DiscourseAntivirus::ClamAv.instance

        render json: DiscourseAntivirus::BackgroundScan.new(antivirus).stats
      end
    end
  end
end
