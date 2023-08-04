# frozen_string_literal: true

module DiscourseAntivirus
  class ClamAVService
    def initialize(hostname, port)
      @hostname = hostname
      @port = port
    end

    def connect!
      begin
        TCPSocket.new(@hostname, @port, connect_timeout: 3)
      rescue StandardError
        nil
      end
    end
  end
end
