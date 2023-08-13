# frozen_string_literal: true

class FakePool < DiscourseAntivirus::ClamAVServicesPool
  def initialize(sockets)
    @sockets = sockets
    @connections = 0
  end

  private

  def connection_factory
    Proc.new { @sockets[@connections].tap { @connections += 1 } }
  end

  def servers
    [OpenStruct.new(hostname: "fake.hostname", port: "8080")]
  end
end
