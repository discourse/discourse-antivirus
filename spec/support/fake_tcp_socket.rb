# frozen_string_literal: true
class FakeTCPSocket
  def initialize(canned_response)
    @canned_response = canned_response
    @received = []
    @next_to_read = 0
  end

  attr_reader :received
  attr_accessor :canned_response

  def flush
    @received = []
  end

  def send(text, _)
    received << text
  end

  def getc
    canned_response[@next_to_read].tap { |_| @next_to_read += 1 }
  end

  def close; end
end
