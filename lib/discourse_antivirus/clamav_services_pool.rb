# frozen_string_literal: true

module DiscourseAntivirus
  class ClamAVServicesPool
    def instances
      @instances ||=
        servers
          .filter { |server| server&.hostname.present? && server&.port.present? }
          .map { |server| ClamAVService.new(server.hostname, server.port) }
    end

    private

    def servers
      @servers ||=
        if Rails.env.production?
          DNSSD::ServiceInstance.new(
            Resolv::DNS::Name.create(SiteSetting.antivirus_srv_record),
          ).targets
        else
          [OpenStruct.new(hostname: GlobalSetting.clamav_hostname, port: GlobalSetting.clamav_port)]
        end
    end
  end
end
