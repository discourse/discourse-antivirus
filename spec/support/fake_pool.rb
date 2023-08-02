# frozen_string_literal: true

class FakePool
  def initialize(sockets)
    @sockets = sockets
  end

  def tcp_socket
    @sockets.first.dup
  end

  def all_tcp_sockets
    @sockets.map(&:dup)
  end
end
