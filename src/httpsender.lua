-- to load local lib files:
package.path = './httplib/?.lua;' .. package.path
package.cpath = './httplib/?.dll;' .. package.cpath

-- test random http query
socket = require "socket"
http = require "socket.http"
print(http.request("https://google.com"))