# frozen_string_literal: true

module DiscourseAntivirus
  class ClamAV
    VIRUS_FOUND = Class.new(StandardError)

    def self.instance
      socket = TCPSocket.new(
        SiteSetting.antivirus_clamav_hostname, SiteSetting.antivirus_clamav_port
      )

      new(socket, Discourse.store)
    end

    def initialize(tcp_socket, store)
      @socket = tcp_socket
      @store = store
    end

    def scan_upload(upload)
      file = get_uploaded_file(upload)
      scan_file(file)
    end

    def scan_file(file)
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

      {
        message: scan_response.gsub('1: stream:', ''),
        found: scan_response.include?('FOUND')
      }
    end

    private

    attr_reader :socket, :store

    def get_uploaded_file(upload)
      if store.external?
        store.download(upload)
      else
        File.open(store.path_for(upload))
      end
    end

    def read_until(socket, delimiter)
      buffer = ''

      while (char = socket.getc) != delimiter
        buffer += char
      end

      buffer
    end
  end
end
