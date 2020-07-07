# frozen_string_literal: true

module DiscourseAntivirus
  class ClamAVServicesPool
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
      @instance ||= DNSSD::ServiceInstance.new(
        Resolv::DNS::Name.create(SiteSetting.antivirus_srv_record)
      )
    end
  end
end
