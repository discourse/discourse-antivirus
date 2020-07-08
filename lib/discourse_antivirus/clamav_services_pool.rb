# frozen_string_literal: true

module DiscourseAntivirus
  class ClamAVServicesPool
    def self.correctly_configured?
      return true if Rails.env.test?

      if Rails.env.production?
        SiteSetting.antivirus_srv_record.present?
      else
        GlobalSetting.respond_to?(:clamav_hostname) && GlobalSetting.respond_to?(:clamav_port)
      end
    end

    def tcp_socket
      build_socket(service_instance.targets.first)
    end

    def all_tcp_sockets
      service_instance.targets.map { |target| build_socket(target) }
    end

    private

    def build_socket(target)
      TCPSocket.new(target.hostname, target.port)
    end

    def service_instance
      @instance ||= if Rails.env.production?
        DNSSD::ServiceInstance.new(
          Resolv::DNS::Name.create(SiteSetting.antivirus_srv_record)
        )
      else
        OpenStruct.new(targets: [
          OpenStruct.new(
            hostname: GlobalSetting.clamav_hostname,
            port: GlobalSetting.clamav_port
          )
        ])
      end
    end
  end
end
