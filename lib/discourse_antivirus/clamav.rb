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

    def self.correctly_configured?
      return true if Rails.env.test?

      if Rails.env.production?
        SiteSetting.antivirus_srv_record.present?
      else
        GlobalSetting.respond_to?(:clamav_hostname) && GlobalSetting.respond_to?(:clamav_port)
      end
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
        clamav_services_pool.online_services.map do |service|
          antivirus_version = service.version.split("/")

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
      unavailable = clamav_services_pool.all_offline?

      PluginStore.set(PLUGIN_NAME, UNAVAILABLE, unavailable)

      !unavailable
    end

    def scan_upload(upload)
      file = get_uploaded_file(upload)

      return error_response(DOWNLOAD_FAILED) if file.nil?

      scan_file(file)
    rescue OpenURI::HTTPError
      error_response(DOWNLOAD_FAILED)
    rescue StandardError => e
      Rails.logger.error("Could not scan upload #{upload.id}. Error: #{e.message}")
      error_response(e.message)
    end

    def scan_file(file)
      online_service = clamav_services_pool.find_online_service

      # We open one connection to check if the service is online and another
      # to scan the file.
      scan_response = online_service&.scan_file(file)
      return error_response(UNAVAILABLE) unless scan_response

      parse_response(scan_response)
    end

    private

    attr_reader :store, :clamav_services_pool

    def error_response(error_message)
      { error: true, found: false, message: error_message }
    end

    def parse_response(scan_response)
      {
        message: scan_response.gsub("stream:", "").gsub("\0", ""),
        found: scan_response.include?("FOUND"),
        error: scan_response.include?("ERROR"),
      }
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
  end
end
