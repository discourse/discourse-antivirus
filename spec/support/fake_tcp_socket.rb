# frozen_string_literal: true
class FakeTCPSocket
  def self.positive(include_pong: false)
    responses = include_pong ? ["1: PONG\0"] : []
    responses << "1: stream: Win.Test.EICAR_HDB-1 FOUND\0"
    new(responses)
  end

  def self.negative(include_pong: false)
    responses = include_pong ? ["1: PONG\0"] : []
    responses << "1: stream: OK\0"
    new(responses)
  end

  def self.error
    new(["1: INSTREAM size limit exceeded. ERROR\0"])
  end

  def initialize(canned_responses)
    @canned_responses = canned_responses
    @received_before_close = []
    @received = []
    @next_to_read = 0
    @current_response = 0
  end

  attr_reader :received, :received_before_close
  attr_accessor :canned_responses

  def sendmsg_nonblock(text, _, _)
    received << text
  end

  def recvmsg_nonblock(maxlen)
    interval_end = @next_to_read + maxlen

    response_chunk = canned_responses[@current_response][@next_to_read..interval_end]

    if response_chunk.ends_with?("\0")
      @current_response += 1
      @next_to_read = 0
    else
      @next_to_read += interval_end + 1
    end

    [response_chunk]
  end

  def close
    @next_to_read = 0
    @received_before_close = @received
    @received = []
  end
end
