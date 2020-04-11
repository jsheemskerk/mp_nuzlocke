-- Script which collects the data required for multiplayer Nuzlocke runs.
-- Based on the scripts by https://github.com/EverOddish.

-- Paths
package.path = 'httplib/?.lua;' .. package.path
package.cpath = 'httplib/?.dll;' .. package.cpath

-- Libraries
http = require "socket.http"

-- Aliases
read_dword = memory.readdwordunsigned
read_word = memory.readwordunsigned
read_byte = memory.readbyteunsigned

-- Tables
data_orders = {
	{0,1,2,3}, {0,1,3,2}, {0,2,1,3}, {0,3,1,2}, {0,2,3,1}, {0,3,2,1},
	{1,0,2,3}, {1,0,3,2}, {2,0,1,3}, {3,0,1,2}, {2,0,3,1}, {3,0,2,1},
	{1,2,0,3}, {1,3,0,2}, {2,1,0,3}, {3,1,0,2}, {2,3,0,1}, {3,2,0,1},
	{1,2,3,0}, {1,3,2,0}, {2,1,3,0}, {3,1,2,0}, {2,3,1,0}, {3,2,1,0}
}
offsets = {
	["dword"] = 4,
	["tid"] = 4,
	["nick"] = 8,
	["block"] = 12,
	["tname"] = 20,
	["data"] = 32,
	["lvl"] = 84,
	["hp"] = 86,
	["slot"] = 100
}
pokes = {}

-- Decrypts the data for a certain pokemon.
function decrypt_data(slot_addr, pid, tid)
	local data = {}
	local data_order = data_orders[(pid % 24) + 1]
	local key = bit.bxor(pid, tid)
	for i = 1, 4 do
		local block = {}
		for j = 1, 3 do
			block[j] = bit.bxor(
				read_dword(
					slot_addr + offsets["data"] +
					data_order[i] * offsets["block"] +
					(j - 1) * offsets["dword"]
				), key
			)
		end
		data[i] = block
	end
	return data
end

-- Retrieves a number of bits from a certain location in a bit string.
function get_bits(bit_str, loc, nbits)
	return bit.rshift(bit_str, loc) % bit.lshift(1, nbits)
end

-- Posts pokemon data to the database.
function post_poke(poke_data, nick)
	local response = {}
	http.request{
		url = "http://joran.fun/db/postpokemon.php",
		method = "POST",
		headers = {
			["Content-Type"] = "application/json",
			["Content-Length"] = poke_data:len()
		},
		source = ltn12.source.string(poke_data),
		sink = ltn12.sink.table(response)
	}
	if string.match(table.concat(response), "duplicate key") then
		print(nick .. " is already in the database.")
	else
		print("Response = " .. table.concat(response))
	end
end

-- Returns the ascii value associated with a certain byte.
function to_ascii(byte)
	if byte >= 0xA1 and byte <= 0xAA then
		return string.char(byte - 113)
	elseif byte == 0xAE then
		return "-"
	elseif byte >= 0xBB and byte <= 0xD4 then
		return string.char(byte - 122)
	elseif byte >= 0xD5 and byte <= 0xEE then
		return string.char(byte - 116)
	else
		return ""
	end
end

-- Updates the database if required.
function update()
	local start_addr = 0x20244EC
	for slot = 1, 6 do
		local slot_addr = start_addr + (slot - 1) * offsets["slot"]
		local pid = read_dword(slot_addr)
		if pid ~= 0 then
			local hp = read_word(slot_addr + offsets["hp"])
			local lvl = read_byte(slot_addr + offsets["lvl"])
			local nick = ""
			for i = 1, 10 do
				nick = nick .. to_ascii(read_byte(slot_addr + offsets["nick"] + (i - 1)))
			end
			if pokes[pid] == nil then
				local tid = read_dword(slot_addr + offsets["tid"])
				local data = decrypt_data(slot_addr, pid, tid)
				local pindex = get_bits(data[1][1], 0, 16)
				local tname = ""
				for i = 1, 7 do
					tname = tname .. to_ascii(read_byte(slot_addr + offsets["tname"] + (i - 1)))
				end
				local ivs = {
					get_bits(data[4][2], 0, 5), get_bits(data[4][2], 5, 5),
					get_bits(data[4][2], 10, 5), get_bits(data[4][2], 20, 5),
					get_bits(data[4][2], 25, 5), get_bits(data[4][2], 15, 5)
				}

				local poke_data = [[{
					"pid": ]] .. pid .. [[,
					"tname": "]] .. tname .. [[",
					"pindex": ]] .. pindex .. [[,
					"nick": "]] .. nick .. [[",
					"lvl": ]] .. lvl .. [[,
					"hpiv": ]] .. ivs[1] .. [[,
					"atkiv": ]] .. ivs[2] .. [[,
					"defiv": ]] .. ivs[3] .. [[,
					"spaiv": ]] .. ivs[4] .. [[,
					"spdiv": ]] .. ivs[5] .. [[,
					"speiv": ]] .. ivs[6] .. [[
				}]]
				pokes[pid] = {["hp"] = hp, ["lvl"] = lvl, ["nick"] = nick}
				post_poke(poke_data, nick)
			end
			if hp == 0 and pokes[pid].hp ~= 0 then
				http.request("http://joran.fun/db/update.php?pid=" .. pid .. "&died")
			end
			if lvl ~= pokes[pid].lvl then
				http.request("http://joran.fun/db/update.php?pid=" .. pid .. "&lvl=" .. lvl)
			end
			if nick ~= pokes[pid].nick then
				http.request("http://joran.fun/db/update.php?pid=" .. pid .. "&nick=" .. nick)
			end
			pokes[pid] = {["hp"] = hp, ["lvl"] = lvl, ["nick"] = nick}
		end
	end
end

-- Applies the update function on a per-frame basis.
gui.register(update)