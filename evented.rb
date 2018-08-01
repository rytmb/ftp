require 'socket'
require_relative './common'

module FTP
  class Evented
    CHUNK_SIZE = 1024 * 16
    include Common

    class Connection
      include Common

      attr_reader :client

      def initialize(io)
        @client = io
        @request, @respose = "", ""
        @handler = CommandHandler.new(self)

        @response = "220 OHAI" + CRLF
      end
      
      def on_data(data)
        @request << data

        if @request.end_with?(CRLF)
          #request is completed.
          @response = @handler.handle(@request) + CRLF
          @request = ""
        end
      end

      def on_writable
        bytes = client.write_nonblock(@response)
        @response.slice!(0, bytes)
      end

      def monitor_for_reading?
        true
      end

      def monitor_for_writing?
        !(@response.empty?)
      end
    end

    def run 
      @handles = {}

      loop do 
        to_read = @handles.values.select(&:monitor_for_reading?).map(&:client)
        to_write = @handles.values.select(&:monitor_for_writing?).map(&:client)

        readables, writables = IO.select(to_read + [@control_socket], to_write)

        readables.each do |socket|
          if socket == @control_socket
            io = @control_socket.accept
            connection = Connection.new(io)
            @handles[io.fileno] = connection

          else
            connection = @handles[socket.fileno]

            begin 
              data = socket.read_nonblock(CHUNK_SIZE)
              connection.on_data(data)
            rescue Errno::EAGAIN
            rescue EOFError
              @handles.delete(socket.fileno)
            end
          end
        end

        writeable.each do |socket|
          connection = @handles[socket.fileno]
          connection.on_writable
      end
    end
  end
end

server = FTP::Evented.new(4422)
server.run