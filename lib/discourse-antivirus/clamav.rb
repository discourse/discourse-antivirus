# frozen_string_literal: true

module DiscourseAntivirus
  class ClamAV
    VIRUS_FOUND = Class.new(StandardError)

    def self.instance
      new(Discourse.store)
    end

    def initialize(store)
      @store = store
    end

    def override_default_socket(socket)
      @socket = socket
    end

    def default_socket
      @socket ||= TCPSocket.new(
        SiteSetting.antivirus_clamav_hostname, SiteSetting.antivirus_clamav_port
      )
    end

    def scan_multiple_uploads(uploads, socket: self.default_socket)
      return [] if uploads.blank?

      open_session(socket)

      results = uploads.each_with_index.map do |upload, index|
        file = get_uploaded_file(upload)
        scan_response = stream_file(socket, file)

        parse_response(scan_response, index + 1).tap do |result|
          result[:upload] = upload
        end
      end

      close_socket(socket)

      results
    end

    def scan_upload(upload, socket: self.default_socket)
      file = get_uploaded_file(upload)

      scan_file(file, socket: socket).tap do |response|
        response[:upload] = upload
      end
    end

    def scan_file(file, socket: self.default_socket)
      open_session(socket)
      scan_response = stream_file(socket, file)
      close_socket(socket)

      parse_response(scan_response)
    end

    private

    attr_reader :store

    def parse_response(scan_response, index = 1)
      {
        message: scan_response.gsub("#{index}: stream:", ''),
        found: scan_response.include?('FOUND')
      }
    end

    def open_session(socket)
      socket.send("nIDSESSION\n", 0)
    end

    def close_socket(socket)
      socket.send("nEND\0", 0)
      socket.close
    end

    def stream_file(socket, file)
      socket.send("zINSTREAM\0", 0)

      while data = file.read(2048)
        socket.send([data.length].pack('N'), 0)
        socket.send(data, 0)
      end

      socket.send([0].pack('N'), 0)
      socket.send('', 0)

      read_until(socket, "\0")
    end

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
