# frozen_string_literal: true

require 'rails_helper'
require_relative '../../support/fake_tcp_socket'

describe DiscourseAntivirus::ClamAV do
  let(:file) do
    Tempfile.new('filename').tap do |f|
      f.write('contents')
    end
  end

  before { file.rewind }

  describe '#virus?' do
    it 'returns false when the file is clear' do
      response = "1: stream: OK\0"
      fake_socket = FakeTCPSocket.new(response)

      scan_result = described_class.new(fake_socket).virus?(file)

      expect(scan_result).to eq(false)
      assert_file_was_sent_through(fake_socket, file)
    end

    it 'returns true when the file has a virus' do
      response = "1: stream: Win.Test.EICAR_HDB-1 FOUND\0"
      fake_socket = FakeTCPSocket.new(response)

      scan_result = described_class.new(fake_socket).virus?(file)

      expect(scan_result).to eq(true)
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
