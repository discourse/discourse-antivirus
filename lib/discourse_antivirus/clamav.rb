# frozen_string_literal: true

module DiscourseAntivirus
  class ClamAV
    VIRUS_FOUND = Class.new(StandardError)
    PLUGIN_NAME = "discourse-antivirus"
    STORE_KEY = "clamav-versions"
    DOWNLOAD_FAILED = "Download failed"
    UNAVAILABLE = "unavailable"

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
      antivirus_versions =
        clamav_services_pool.all_tcp_sockets.map do |tcp_socket|
          antivirus_version =
            with_session(socket: tcp_socket) { |socket| write_in_socket(socket, "zVERSION\0") }

          antivirus_version = clean_msg(antivirus_version).split("/")

          {
            antivirus: antivirus_version[0],
            database: antivirus_version[1].to_i,
            updated_at: antivirus_version[2],
          }
        end

      PluginStore.set(PLUGIN_NAME, STORE_KEY, antivirus_versions)
      antivirus_versions
    end

    def accepting_connections?
      available = clamav_services_pool.all_tcp_sockets.any? { |socket| target_online?(socket) }

      update_status(!available)

      available
    end

    def scan_upload(upload)
      begin
        file = get_uploaded_file(upload)

        return error_response(DOWNLOAD_FAILED) if file.nil?

        scan_file(file)
      rescue OpenURI::HTTPError
        error_response(DOWNLOAD_FAILED)
      rescue StandardError => e
        Rails.logger.error("Could not scan upload #{upload.id}. Error: #{e.message}")
        error_response(e.message)
      end
    end

    def scan_file(file)
      scan_response = with_session { |socket| stream_file(socket, file) }

      parse_response(scan_response)
    end

    private

    attr_reader :store, :clamav_services_pool

    def error_response(error_message)
      { error: true, found: false, message: error_message }
    end

    def update_status(unavailable)
      PluginStore.set(PLUGIN_NAME, UNAVAILABLE, unavailable)
    end

    def target_online?(socket)
      return false if socket.nil?

      ping_result = with_session(socket: socket) { |s| write_in_socket(s, "zPING\0") }

      clean_msg(ping_result) == "PONG"
    end

    def clean_msg(raw)
      raw.gsub("1: ", "").strip
    end

    def with_session(socket: nil)
      socket ||= clamav_services_pool.all_tcp_sockets.shuffle.find { |s| target_online?(s) }
      raise "no online socket found" if !socket

      write_in_socket(socket, "zIDSESSION\0")

      yield(socket)

      write_in_socket(socket, "zEND\0")

      response = get_full_response_from(socket)
      socket.close
      response
    end

    def parse_response(scan_response)
      {
        message: scan_response.gsub("1: stream:", "").gsub("\0", ""),
        found: scan_response.include?("FOUND"),
        error: scan_response.include?("ERROR"),
      }
    end

    def stream_file(socket, file)
      write_in_socket(socket, "zINSTREAM\0")

      while data = file.read(2048)
        write_in_socket(socket, [data.length].pack("N"))
        write_in_socket(socket, data)
      end

      write_in_socket(socket, [0].pack("N"))
      write_in_socket(socket, "")
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

    # ClamAV wants us to read/write in a non-blocking manner to prevent deadlocks.
    # Read more about this [here](https://manpages.debian.org/testing/clamav-daemon/clamd.8.en.html#IDSESSION,)
    #
    # We need to peek into the socket buffer to make sure we can write/read from it,
    # or we risk ClamAV abruptly closing the connection.
    # For that, we use [IO#select](https://www.rubydoc.info/stdlib/core/IO.select)
    def write_in_socket(socket, msg)
      IO.select(nil, [socket])
      socket.sendmsg_nonblock(msg, 0, nil)
    end

    def read_from_socket(socket)
      IO.select([socket])

      # Returns an array with the chunk as the first element
      socket.recvmsg_nonblock(25).to_a.first.to_s
    end

    def get_full_response_from(socket)
      buffer = ""

      buffer += read_from_socket(socket) until buffer.ends_with?("\0")

      buffer
    end
  end
end
