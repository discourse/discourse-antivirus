# frozen_string_literal: true

module DiscourseAntivirus
  class ClamAVServicesPool
    def online_services
      instances.select(&:online?)
    end

    def all_offline?
      instances.none?(&:online?)
    end

    def find_online_service
      instances.find(&:online?)
    end

    private

    def connection_factory
      @factory ||=
        Proc.new do |hostname, port|
          begin
            TCPSocket.new(hostname, port, connect_timeout: 3)
          rescue StandardError
            nil
          end
        end
    end

    def instances
      @instances ||=
        servers
          .filter { |server| server&.hostname.present? && server&.port.present? }
          .map { |server| ClamAVService.new(connection_factory, server.hostname, server.port) }
    end

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
