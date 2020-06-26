# frozen_string_literal: true

require 'rails_helper'
require_relative '../../support/fake_tcp_socket'

describe DiscourseAntivirus::ClamAV do
  fab!(:upload) { Fabricate(:image_upload) }
  let(:file) { File.open(File.open(Discourse.store.path_for(upload))) }

  let(:antivirus) { described_class.new(Discourse.store) }

  before { file.rewind }

  describe '#scan_upload' do
    it 'returns false when the file is clear' do
      fake_socket = FakeTCPSocket.negative

      scan_result = antivirus.scan_upload(upload, socket: fake_socket)

      expect(scan_result[:found]).to eq(false)
      assert_file_was_sent_through(fake_socket, file)
    end

    it 'returns true when the file has a virus' do
      fake_socket = FakeTCPSocket.positive

      scan_result = antivirus.scan_upload(upload, socket: fake_socket)

      expect(scan_result[:found]).to eq(true)
      assert_file_was_sent_through(fake_socket, file)
    end
  end

  describe '#version' do
    let(:antivirus_version) { 'ClamAV 0.102.3' }
    let(:database_version) { '25853' }
    let(:last_update) { 'Wed Jun 24 10:13:27 2020' }

    let(:socket) { FakeTCPSocket.new("1: #{antivirus_version}/#{database_version}/#{last_update}\0") }

    it 'returns the version from the plugin store after fetching the last one' do
      antivirus.update_version(socket: socket)
      version = antivirus.version

      expect(version[:antivirus]).to eq(antivirus_version)
      expect(version[:database]).to eq(database_version)
      expect(version[:updated_at]).to eq(last_update)
      assert_version_was_requested(socket)
    end

    it 'directly returns the version from the plugin store without fetching' do
      version_data = { antivirus: antivirus_version, database: database_version, updated_at: last_update }
      PluginStore.set(described_class::PLUGIN_NAME, described_class::STORE_KEY, version_data)

      version = antivirus.version

      expect(version[:antivirus]).to eq(antivirus_version)
      expect(version[:database]).to eq(database_version)
      expect(version[:updated_at]).to eq(last_update)
      expect(socket.received).to be_empty
    end

    it 'fetches the last version if the plugin store does not have it' do
      version = antivirus.version(socket: socket)

      expect(version[:antivirus]).to eq(antivirus_version)
      expect(version[:database]).to eq(database_version)
      expect(version[:updated_at]).to eq(last_update)
      assert_version_was_requested(socket)
    end
  end

  def assert_version_was_requested(fake_socket)
    expected = [
      "nIDSESSION\n",
      "zVERSION\0",
      "nEND\0"
    ]

    expect(fake_socket.received).to contain_exactly(*expected)
  end

  def assert_file_was_sent_through(fake_socket, file)
    expected = [
      "nIDSESSION\n",
      "zINSTREAM\0",
    ]

    file.rewind
    while data = file.read(2048)
      expected << [data.length].pack('N')
      expected << data
    end

    expected << [0].pack('N')
    expected << ''

    expected << "nEND\0"

    expect(fake_socket.received).to contain_exactly(*expected)
  end
end
