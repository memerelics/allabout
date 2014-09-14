# $ ri TCPSocket

= TCPSocket < IPSocket

(from ruby core)
------------------------------------------------------------------------------
TCPSocket represents a TCP/IP client socket.

A simple client may look like:

  require 'socket'

  s = TCPSocket.new 'localhost', 2000

  while line = s.gets # Read lines from socket
    puts line         # and print them
  end

  s.close             # close socket when done

------------------------------------------------------------------------------
= Class methods:

  gethostbyname, new
