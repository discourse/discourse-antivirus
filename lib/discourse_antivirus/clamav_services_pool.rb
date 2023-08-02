# frozen_string_literal: true

module DiscourseAntivirus
  class ClamAVServicesPool
    UNAVAILABLE = "unavailable"

    def self.correctly_configured?
      return true if Rails.env.test?

      if Rails.env.production?
        SiteSetting.antivirus_srv_record.present?
      else
        GlobalSetting.respond_to?(:clamav_hostname) && GlobalSetting.respond_to?(:clamav_port)
      end
    end

    def all_tcp_sockets
      service_instance.targets.map { |target| build_socket(target) }
    end

    private

    def build_socket(target)
      return if target.nil?
      return if target.hostname.blank?
      return if target.port.blank?

      begin
        TCPSocket.new(target.hostname, target.port, connect_timeout: 3)
      rescue StandardError
        nil
      end
    end

    def service_instance
      @instance ||=
        if Rails.env.production?
          DNSSD::ServiceInstance.new(Resolv::DNS::Name.create(SiteSetting.antivirus_srv_record))
        else
          OpenStruct.new(
            targets: [
              OpenStruct.new(
                hostname: GlobalSetting.clamav_hostname,
                port: GlobalSetting.clamav_port,
              ),
            ],
          )
        end
    end
  end
end
