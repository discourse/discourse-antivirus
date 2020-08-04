# frozen_string_literal: true

module DiscourseAntivirus
  class ClamAV
    VIRUS_FOUND = Class.new(StandardError)
    PLUGIN_NAME = 'discourse-antivirus'
    STORE_KEY = 'clamav-versions'
    DOWNLOAD_FAILED = 'Download failed'
    TRANSMISSION_FAILED = 'Failed to send data to ClamAV'

    def self.instance
      new(Discourse.store, DiscourseAntivirus::ClamAVServicesPool.new)
    end

    def initialize(store, clamav_services_pool)
      @store = store
      @clamav_services_pool = clamav_services_pool
    end

    def versions
      PluginStore.get(PLUGIN_NAME, STORE_KEY) || update_versions
    end

    def update_versions
      antivirus_versions = clamav_services_pool.all_tcp_sockets.map do |tcp_socket|
        antivirus_version = with_session(socket: tcp_socket) do |socket|
          socket.send("zVERSION\0", 0)
          read_until(socket, "\0")
        end

        antivirus_version = antivirus_version.gsub('1: ', '').strip.split('/')

        {
          antivirus: antivirus_version[0],
          database: antivirus_version[1].to_i,
          updated_at: antivirus_version[2]
        }
      end

      PluginStore.set(PLUGIN_NAME, STORE_KEY, antivirus_versions)
      antivirus_versions
    end

    def scan_multiple_uploads(uploads)
      return [] if uploads.blank?

      uploads.map do |upload|
        result = begin
          file = get_uploaded_file(upload)
          with_session do |socket|
            scan_response = stream_file(socket, file)
            parse_response(scan_response)
          end
        rescue OpenURI::HTTPError
          { error: true, found: '', message: DOWNLOAD_FAILED }
        rescue Errno::EPIPE
          { error: true, found: '', message: TRANSMISSION_FAILED }
        end

        result[:upload] = upload
        yield(upload, result) if block_given?
        result
      end
    end

    def scan_upload(upload)
      file = get_uploaded_file(upload)

      scan_file(file).tap do |response|
        response[:upload] = upload
      end
    end

    def scan_file(file)
      scan_response = with_session { |socket| stream_file(socket, file) }

      parse_response(scan_response)
    end

    private

    attr_reader :store, :clamav_services_pool

    def with_session(socket: clamav_services_pool.tcp_socket)
      open_session(socket)
      yield(socket).tap { |_| close_socket(socket) }
    end

    def parse_response(scan_response)
      {
        message: scan_response.gsub("1: stream:", ''),
        found: scan_response.include?('FOUND'),
        error: false
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
        size_in_kb = upload.filesize / 1000
        store.download(upload, max_file_size_kb: size_in_kb)
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
