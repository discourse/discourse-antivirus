# frozen_string_literal: true

module DiscourseAntivirus
  class ClamAVHealthMetric < ::DiscoursePrometheus::InternalMetric::Custom
    attribute :name, :labels, :description, :value, :type

    def initialize
      @name = "clamav_available"
      @description = "Whether or not ClamAV is accepting connections"
      @type = "Gauge"
    end

    def collect
      @@clamav_stats ||= {}
      last_check = @@clamav_stats[:last_check]

      if (!last_check || should_recheck?(last_check))
        antivirus = DiscourseAntivirus::ClamAV.instance
        available = antivirus.accepting_connections? ? 1 : 0

        @@clamav_stats[:status] = available
        @@clamav_stats[:last_check] = Time.now.to_i
      end

      @value = @@clamav_stats[:status]
    end

    private

    def should_recheck?(last_check)
      interval_seconds = 60

      Time.now.to_i - last_check > interval_seconds
    end
  end
end
