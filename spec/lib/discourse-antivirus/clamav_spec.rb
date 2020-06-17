# frozen_string_literal: true

require 'rails_helper'
require_relative '../../support/fake_tcp_socket'

describe DiscourseAntivirus::ClamAV do
  fab!(:upload) { Fabricate(:image_upload) }
  let(:file) { File.open(File.open(Discourse.store.path_for(upload))) }

  before { file.rewind }

  describe '#scan_upload' do
    it 'returns false when the file is clear' do
      fake_socket = FakeTCPSocket.negative

      scan_result = described_class.new(fake_socket, Discourse.store).scan_upload(upload)

      expect(scan_result[:found]).to eq(false)
      assert_file_was_sent_through(fake_socket, file)
    end

    it 'returns true when the file has a virus' do
      fake_socket = FakeTCPSocket.positive

      scan_result = described_class.new(fake_socket, Discourse.store).scan_upload(upload)

      expect(scan_result[:found]).to eq(true)
      assert_file_was_sent_through(fake_socket, file)
    end
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

    expect(fake_socket.received).to contain_exactly(*expected)
  end
end
