# frozen_string_literal: true

module DiscourseAntivirus
  class ClamAvService
    def initialize(connection_factory, hostname, port)
      @connection_factory = connection_factory
      @hostname = hostname
      @port = port
    end

    def version
      with_session { |s| write_in_socket(s, "zVERSION\0") }
    end

    def online?
      ping_result = with_session { |s| write_in_socket(s, "zPING\0") }

      ping_result == "PONG"
    end

    def scan_file(file)
      with_session do |socket|
        write_in_socket(socket, "zINSTREAM\0")

        while data = file.read(2048)
          write_in_socket(socket, [data.length].pack("N"))
          write_in_socket(socket, data)
        end

        write_in_socket(socket, [0].pack("N"))
        write_in_socket(socket, "")
      end
    end

    private

    attr_reader :connection_factory, :hostname, :port, :connection

    def with_session
      socket = connection_factory.call(hostname, port)
      return if socket.nil?

      write_in_socket(socket, "zIDSESSION\0")

      yield(socket)

      write_in_socket(socket, "zEND\0")

      response = get_full_response_from(socket)
      socket.close
      response
    end

    # ClamAV wants us to read/write in a non-blocking manner to prevent deadlocks.
    # Read more about this [here](https://manpages.debian.org/testing/clamav-daemon/clamd.8.en.html#IDSESSION,)
    #
    # We need to peek into the socket buffer to make sure we can write/read from it,
    # or we risk ClamAV abruptly closing the connection.
    # For that, we use [IO#select](https://www.rubydoc.info/stdlib/core/IO.select)
    def write_in_socket(socket, msg)
      IO.select(nil, [socket])
      socket.sendmsg_nonblock(msg, 0, nil)
    end

    def get_full_response_from(socket)
      buffer = +""

      until buffer.ends_with?("\0")
        IO.select([socket])

        # Returns an array with the chunk as the first element
        buffer << socket.recvmsg_nonblock(25).to_a.first.to_s
      end

      buffer.gsub("1: ", "").strip
    end
  end
end
