# frozen_string_literal: true

module DiscourseAntivirus
  class ClamAV
    VIRUS_FOUND = Class.new(StandardError)
    PLUGIN_NAME = 'discourse-antivirus'
    STORE_KEY = 'clamav-versions'
    DOWNLOAD_FAILED = 'Download failed'
    UNAVAILABLE = 'unavailable'

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

        antivirus_version = clean_msg(antivirus_version).split('/')

        {
          antivirus: antivirus_version[0],
          database: antivirus_version[1].to_i,
          updated_at: antivirus_version[2]
        }
      end

      PluginStore.set(PLUGIN_NAME, STORE_KEY, antivirus_versions)
      antivirus_versions
    end

    def accepting_connections?
      sockets = clamav_services_pool.all_tcp_sockets

      if sockets.empty?
        update_status(true)
        return false
      end

      available = sockets.reduce(true) do |memo, socket|
        memo && target_online?(socket)
      end

      available.tap do |status|
        unavailable = !status
        update_status(unavailable)
      end
    end

    def scan_upload(upload)
      begin
        file = get_uploaded_file(upload)
        scan_file(file)
      rescue OpenURI::HTTPError
        { error: true, found: '', message: DOWNLOAD_FAILED }
      rescue StandardError => e
        Rails.logger.error("Could not scan upload #{upload.id}. Error: #{e.message}")
        { error: true, found: '', message: e.message }
      end
    end

    def scan_file(file)
      scan_response = with_session { |socket| stream_file(socket, file) }

      parse_response(scan_response)
    end

    private

    attr_reader :store, :clamav_services_pool

    def update_status(unavailable)
      PluginStore.set(PLUGIN_NAME, UNAVAILABLE, unavailable)
    end

    def target_online?(socket)
      return false if socket.nil?

      ping_result = with_session(socket: socket) do |s|
        s.send("zPING\0", 0)
        read_until(s, "\0")
      end

      clean_msg(ping_result) == 'PONG'
    end

    def clean_msg(raw)
      raw.gsub('1: ', '').strip
    end

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
        # Upload#filesize could be approximate.
        # add two extra Mbs to make sure that we'll be able to download the upload.
        max_filesize = upload.filesize + 2.megabytes
        store.download(upload, max_file_size_kb: max_filesize)
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
