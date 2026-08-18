# frozen_string_literal: true

require "socket"

class FakeTCPSocket
  def self.online
    new("1: PONG\0")
  end

  def self.positive
    new("1: stream: Win.Test.EICAR_HDB-1 FOUND\0")
  end

  def self.negative
    new("1: stream: OK\0")
  end

  def self.error
    new("1: INSTREAM size limit exceeded. ERROR\0")
  end

  def initialize(canned_response)
    @canned_response = canned_response
    @closed = false
    @received_before_close = []
    @received = []
    @next_to_read = 0

    # ClamAvService peeks into the socket with IO.select before every read and
    # write. Backing the fake with a real socket pair lets those calls resolve
    # through #to_io instead of forcing specs to stub IO.select globally, which
    # would also intercept unrelated core code (e.g. Landlock reading a
    # subprocess' output while ImageMagick runs).
    @io, @peer = UNIXSocket.pair
    @peer.write("\0") # nothing ever reads this, so @io stays readable
  end

  attr_reader :received, :received_before_close
  attr_accessor :canned_response

  def to_io
    @io
  end

  def sendmsg_nonblock(text, _, _)
    raise if @closed

    received << text
  end

  def recvmsg_nonblock(maxlen)
    raise if @closed

    interval_end = @next_to_read + maxlen

    response_chunk = canned_response[@next_to_read..interval_end]

    @next_to_read += interval_end + 1 unless response_chunk.ends_with?("\0")

    [response_chunk]
  end

  def close
    @closed = true
    @received_before_close = @received
    @io.close
    @peer.close
  end
end
