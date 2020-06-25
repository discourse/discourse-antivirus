# frozen_string_literal: true
class FakeTCPSocket
  def self.positive
    new("1: stream: Win.Test.EICAR_HDB-1 FOUND\0")
  end

  def self.negative
    new("1: stream: OK\0")
  end

  def initialize(canned_response)
    @canned_response = canned_response
    @received = []
    @next_to_read = 0
  end

  attr_reader :received
  attr_accessor :canned_response

  def send(text, _)
    received << text
  end

  def getc
    canned_response[@next_to_read].tap { |_| @next_to_read += 1 }
  end

  def close; end
end
