# frozen_string_literal: true

# name: discourse-antivirus
# about: Scan uploads
# version: 0.1
# authors: romanrizzi
# url: https://github.com/romanrizzi

enabled_site_setting :discourse_antivirus_enabled

PLUGIN_NAME ||= 'DiscourseAntivirus'

load File.expand_path('lib/discourse-antivirus/engine.rb', __dir__)

after_initialize do
  require_dependency File.expand_path('../lib/discourse-antivirus/clamav.rb', __FILE__)
  require_dependency File.expand_path('../spec/support/fake_tcp_socket.rb', __FILE__)

  on(:before_upload_creation) do |file|
    response = "1: stream: Win.Test.EICAR_HDB-1 FOUND\0"
    fake_socket = FakeTCPSocket.new(response)

    if DiscourseAntivirus::ClamAV.new(fake_socket).virus?(file)
      raise DiscourseAntivirus::ClamAV::VIRUS_FOUND, I18n.t('scan.virus_found')
    end
  end
end
