# frozen_string_literal: true

require 'rails_helper'
require_relative 'support/fake_tcp_socket'

describe 'plugin live scanning' do
  before { SiteSetting.discourse_antivirus_enabled = true }

  fab!(:user) { Fabricate(:user) }

  describe 'exporting files' do
    before { SiteSetting.authorized_extensions = 'pdf' }

    let(:filename) { "small.pdf" }
    let(:file) { file_from_fixtures(filename, "pdf") }

    it 'scans regular files' do
      DiscourseAntivirus::ClamAV.expects(:instance).returns(build_antivirus(FakeTCPSocket.positive))

      expect {
        UploadCreator.new(file, filename).create_for(user.id)
      }.to raise_error DiscourseAntivirus::ClamAV::VIRUS_FOUND
    end

    it 'skips the file if it was tagged for export' do
      expect {
        UploadCreator.new(file, filename, for_export: 'true').create_for(user.id)
      }.not_to raise_error
    end
  end

  describe 'images' do
    let(:filename) { 'logo.png' }
    let(:file) { file_from_fixtures(filename) }

    it 'skips images by default' do
      expect {
        UploadCreator.new(file, filename).create_for(user.id)
      }.not_to raise_error
    end

    it 'scans the image if the live scan images setting is enabled' do
      SiteSetting.antivirus_live_scan_images = true

      DiscourseAntivirus::ClamAV.expects(:instance).returns(build_antivirus(FakeTCPSocket.positive))

      expect {
        UploadCreator.new(file, filename).create_for(user.id)
      }.to raise_error DiscourseAntivirus::ClamAV::VIRUS_FOUND
    end
  end

  def build_antivirus(socket)
    pool = OpenStruct.new(tcp_socket: socket, all_tcp_sockets: [socket])
    DiscourseAntivirus::ClamAV.new(Discourse.store, pool)
  end
end
