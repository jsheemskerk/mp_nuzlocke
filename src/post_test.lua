package.path = 'httplib/?.lua;' .. package.path
package.cpath = 'httplib/?.dll;' .. package.cpath

http = require "socket.http"

sent = false

function send()
	if sent == false then
		data = [[{
			"phash": 122,
			"tid": 5,
			"pid": 128,
			"hpiv": 12,
			"atkiv": 1,
			"defiv": 3,
			"spaiv": 11,
			"spdiv": 11,
			"speiv": 22,
			"lvl": 12
		}]]
		http.request{
			url = "http://joran.fun/db/postpokemon.php",
			method = "POST",
			headers = {
				["Content-Type"] = "application/json",
				["Content-Length"] = data:len()
			},
			source = ltn12.source.string(data)
		}
	end
	sent = true
end

gui.register(send)