# frozen_string_literal: true

require 'rails_helper'
require_relative 'support/fake_tcp_socket'

describe 'plugin live scanning' do
  before { SiteSetting.discourse_antivirus_enabled = true }

  fab!(:user) { Fabricate(:user) }

  describe 'regular files' do
    before { SiteSetting.authorized_extensions = 'pdf' }

    let(:filename) { 'small.pdf' }
    let(:file) { file_from_fixtures(filename, 'pdf') }

    it 'scans regular files and adds an error if the scan result is positive' do
      mock_antivirus(FakeTCPSocket.positive(include_pong: true))

      scanned_upload = UploadCreator.new(file, filename).create_for(user.id)

      expect(scanned_upload.errors.to_a).to contain_exactly(I18n.t('scan.virus_found'))
    end

    it "scans regular files but does nothing if the scan result is negative" do
      mock_antivirus(FakeTCPSocket.negative(include_pong: true))

      scanned_upload = UploadCreator.new(file, filename).create_for(user.id)

      expect(scanned_upload.errors.to_a).to be_empty
    end

    it 'skips the file if it was tagged for export' do
      SiteSetting.export_authorized_extensions = 'pdf'
      upload = UploadCreator.new(file, filename, for_export: 'true').create_for(user.id)

      expect(upload.errors).to be_empty
    end

    it 'skips the file if the skip_validations option is true' do
      upload = UploadCreator.new(file, filename, skip_validations: true).create_for(user.id)

      expect(upload.errors).to be_empty
    end

    it 'skips files if the upload is not valid' do
      SiteSetting.max_attachment_size_kb = 0

      upload = UploadCreator.new(file, filename).create_for(user.id)

      expect(upload.persisted?).to eq(false)
    end

    context 'when we cannot establish a connection with ClamAV' do
      it 'skips the upload' do
        mock_antivirus(nil)

        upload = UploadCreator.new(file, filename).create_for(user.id)

        expect(upload.errors).to be_empty
      end
    end
  end

  describe 'images' do
    let(:filename) { 'logo.png' }
    let(:file) { file_from_fixtures(filename) }

    it 'skips images by default' do
      upload = UploadCreator.new(file, filename).create_for(user.id)

      expect(upload.errors).to be_empty
    end

    it 'scans the image if the live scan images setting is enabled' do
      SiteSetting.antivirus_live_scan_images = true
      mock_antivirus(FakeTCPSocket.positive(include_pong: true))

      scanned_upload = UploadCreator.new(file, filename).create_for(user.id)

      expect(scanned_upload.errors.to_a).to contain_exactly(I18n.t('scan.virus_found'))
    end
  end

  def mock_antivirus(socket)
    pool = OpenStruct.new(tcp_socket: socket, all_tcp_sockets: [socket])
    antivirus = DiscourseAntivirus::ClamAV.new(Discourse.store, pool)
    DiscourseAntivirus::ClamAV.expects(:instance).returns(antivirus)
  end
end

describe 'Updating the ClamAV version after enabling the plugin' do
  it 'enqueues a job to fetch the latest version' do
    SiteSetting.antivirus_srv_record = 'srv.record'

    expect { SiteSetting.discourse_antivirus_enabled = true }.to change(Jobs::FetchAntivirusVersion.jobs, :size).by(1)
  end

  it 'does nothing' do
    expect { SiteSetting.discourse_antivirus_enabled = false }.to change(Jobs::FetchAntivirusVersion.jobs, :size).by(0)
  end
end
