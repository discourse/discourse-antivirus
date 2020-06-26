# frozen_string_literal: true

module DiscourseAntivirus
  class ClamAV
    PLUGIN_NAME = 'discourse-antivirus'
    STORE_KEY = 'clamav-version'

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

    def version(socket: self.default_socket)
      PluginStore.get(PLUGIN_NAME, STORE_KEY) || update_version(socket: socket)
    end

    def update_version(socket: self.default_socket)
      antivirus_version = with_session(socket) do
        socket.send("zVERSION\0", 0)
        read_until(socket, "\0")
      end

      antivirus_version = antivirus_version.gsub('1: ', '').strip.split('/')
      antivirus_version = {
        antivirus: antivirus_version[0],
        database: antivirus_version[1],
        updated_at: antivirus_version[2]
      }

      PluginStore.set(PLUGIN_NAME, STORE_KEY, antivirus_version)
      antivirus_version
    end

    def scan_multiple_uploads(uploads, socket: self.default_socket)
      return [] if uploads.blank?

      with_session(socket) do
        uploads.each_with_index.map do |upload, index|
          file = get_uploaded_file(upload)
          scan_response = stream_file(socket, file)

          parse_response(scan_response, index + 1).tap do |result|
            result[:upload] = upload
          end
        end
      end
    end

    def scan_upload(upload, socket: self.default_socket)
      file = get_uploaded_file(upload)

      scan_file(file, socket: socket).tap do |response|
        response[:upload] = upload
      end
    end

    def scan_file(file, socket: self.default_socket)
      scan_response = with_session(socket) { stream_file(socket, file) }

      parse_response(scan_response)
    end

    private

    attr_reader :store

    def with_session(socket)
      open_session(socket)
      yield.tap { |_| close_socket(socket) }
    end

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
