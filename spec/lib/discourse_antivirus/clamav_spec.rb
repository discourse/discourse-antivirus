# frozen_string_literal: true

require "rails_helper"
require_relative "../../support/fake_tcp_socket"

describe DiscourseAntivirus::ClamAV do
  fab!(:upload) { Fabricate(:image_upload) }
  let(:file) { File.open(Discourse.store.path_for(upload)) }

  before do
    file.rewind
    IO.stubs(:select)
  end

  describe "#scan_upload" do
    it "returns false when the file is clear" do
      fake_socket = FakeTCPSocket.negative
      pool = build_fake_pool(socket: fake_socket)
      antivirus = build_antivirus(pool)

      scan_result = antivirus.scan_upload(upload)

      expect(scan_result[:found]).to eq(false)
      assert_file_was_sent_through(fake_socket, file)
    end

    it "returns true when the file has a virus" do
      fake_socket = FakeTCPSocket.positive
      pool = build_fake_pool(socket: fake_socket)
      antivirus = build_antivirus(pool)

      scan_result = antivirus.scan_upload(upload)

      expect(scan_result[:found]).to eq(true)
      assert_file_was_sent_through(fake_socket, file)
    end

    it "detects if ClamAV returned an error" do
      fake_socket = FakeTCPSocket.error
      pool = build_fake_pool(socket: fake_socket)
      antivirus = build_antivirus(pool)

      scan_result = antivirus.scan_upload(upload)

      expect(scan_result[:message]).to include("ERROR")
      expect(scan_result[:found]).to eq(false)
      expect(scan_result[:error]).to eq(true)
      assert_file_was_sent_through(fake_socket, file)
    end
  end

  describe "#version" do
    let(:antivirus_version) { "ClamAV 0.102.3" }
    let(:database_version) { "25853" }
    let(:last_update) { "Wed Jun 24 10:13:27 2020" }

    let(:socket) do
      FakeTCPSocket.new(["1: #{antivirus_version}/#{database_version}/#{last_update}\0"])
    end

    let(:antivirus) { build_antivirus(build_fake_pool(socket: socket)) }

    it "returns the version from the plugin store after fetching the last one" do
      antivirus.update_versions
      version = antivirus.versions.first

      expect(version[:antivirus]).to eq(antivirus_version)
      expect(version[:database]).to eq(database_version.to_i)
      expect(version[:updated_at]).to eq(last_update)
      assert_version_was_requested(socket)
    end

    it "directly returns the version from the plugin store without fetching" do
      version_data = {
        antivirus: antivirus_version,
        database: database_version.to_i,
        updated_at: last_update,
      }
      PluginStore.set(described_class::PLUGIN_NAME, described_class::STORE_KEY, [version_data])

      version = antivirus.versions.first

      expect(version[:antivirus]).to eq(antivirus_version)
      expect(version[:database]).to eq(database_version.to_i)
      expect(version[:updated_at]).to eq(last_update)
      expect(socket.received).to be_empty
    end

    it "fetches the last version if the plugin store does not have it" do
      version = antivirus.versions.first

      expect(version[:antivirus]).to eq(antivirus_version)
      expect(version[:database]).to eq(database_version.to_i)
      expect(version[:updated_at]).to eq(last_update)
      assert_version_was_requested(socket)
    end
  end

  def assert_version_was_requested(fake_socket)
    expected = ["zIDSESSION\0", "zVERSION\0", "zEND\0"]

    expect(fake_socket.received_before_close).to contain_exactly(*expected)
    expect(fake_socket.received).to be_empty
  end

  def assert_file_was_sent_through(fake_socket, file)
    expected = ["zPING\0", "zIDSESSION\0", "zINSTREAM\0"]

    file.rewind
    while data = file.read(2048)
      expected << [data.length].pack("N")
      expected << data
    end

    expected << [0].pack("N")
    expected << ""

    expected << "zEND\0"

    expect(fake_socket.received_before_close).to contain_exactly(*expected)
    expect(fake_socket.received).to be_empty
  end

  def build_fake_pool(socket:)
    OpenStruct.new(tcp_socket: socket, all_tcp_sockets: [socket])
  end

  def build_antivirus(pool)
    described_class.new(Discourse.store, pool)
  end
end
