# frozen_string_literal: true

module DiscourseAntivirus
  class ClamAV
    VIRUS_FOUND = Class.new(StandardError)

    def self.instance
      socket = TCPSocket.new(SiteSetting.clamav_host, SiteSetting.clamav_port)

      new(socket)
    end

    def initialize(tcp_socket)
      @socket = tcp_socket
    end

    def virus?(file)
      socket.send("nIDSESSION\n", 0)
      socket.send("zINSTREAM\0", 0)

      while data = file.read(2048)
        socket.send([data.length].pack('N'), 0)
        socket.send(data, 0)
      end

      socket.send([0].pack('N'), 0)
      socket.send('', 0)

      scan_response = read_until(socket, "\0")
      socket.close

      scan_response.include?('FOUND')
    end

    private

    attr_reader :socket

    def read_until(socket, delimiter)
      buffer = ''

      while (char = socket.getc) != delimiter
        buffer += char
      end

      buffer
    end
  end
end
