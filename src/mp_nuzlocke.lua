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
party = {}

-- Prints a value when 'D' is pressed.
function debug(value)
	if input.get()["D"] then
		print(value)
	end
end

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

-- Posts data to an URL via a HTTP request.
function http_post(url, data)
end

-- Posts the pokemon in the given slot to the database.
function post_poke(poke)
	local data = [[{
		"pid": ]] .. poke.pid .. [[,
		"tname": "]] .. poke.tname .. [[",
		"pindex": ]] .. poke.pindex .. [[,
		"nick": "]] .. poke.nick .. [[",
		"lvl": ]] .. poke.lvl .. [[,
		"hpiv": ]] .. poke.hpiv .. [[,
		"atkiv": ]] .. poke.atkiv .. [[,
		"defiv": ]] .. poke.defiv .. [[,
		"spaiv": ]] .. poke.spaiv .. [[,
		"spdiv": ]] .. poke.spdiv .. [[,
		"speiv": ]] .. poke.speiv .. [[
	}]]

	local response = {}
	http.request{
		url = "http://joran.fun/db/postpokemon.php",
		method = "POST",
		headers = {
			["Content-Type"] = "application/json",
			["Content-Length"] = data:len()
		},
		source = ltn12.source.string(data),
		sink = ltn12.sink.table(response)
	}
	if string.match(table.concat(response), "duplicate key") then
		print(poke.nick .. " is already in the database.")
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

-- Updates the database as required.
function update()
	local start_addr = 0x20244EC
	for slot = 1, 6 do
		local slot_addr = start_addr + (slot - 1) * offsets["slot"]
		local pid = read_dword(slot_addr)
		local tid = read_dword(slot_addr + offsets["tid"])
		local lvl = read_byte(slot_addr + offsets["lvl"])
		local hp = read_word(slot_addr + offsets["hp"])
		local data = decrypt_data(slot_addr, pid, tid)
		if party[slot] == nil and pid ~= 0 then
			local pindex = get_bits(data[1][1], 0, 16)
			local tname = ""
			for i = 1, 7 do
				tname = tname .. to_ascii(read_byte(slot_addr + offsets["tname"] + (i - 1)))
			end
			local nick = ""
			for i = 1, 10 do
				nick = nick .. to_ascii(read_byte(slot_addr + offsets["nick"] + (i - 1)))
			end
			local ivs = {
				get_bits(data[4][2], 0, 5), get_bits(data[4][2], 5, 5),
				get_bits(data[4][2], 10, 5), get_bits(data[4][2], 20, 5),
				get_bits(data[4][2], 25, 5), get_bits(data[4][2], 15, 5)
			}

			party[slot] = {
				["pid"] = pid, ["tid"] = tid, ["tname"] = tname,
				["pindex"] = pindex, ["nick"] = nick, ["lvl"] = lvl, ["hp"] = hp,
				["hpiv"] = ivs[1], ["atkiv"] = ivs[2], ["defiv"] = ivs[3], 
				["spaiv"] = ivs[4], ["spdiv"] = ivs[5], ["speiv"] = ivs[6], 
			}
			post_poke(party[slot])
		elseif party[slot] ~= nil then
			if hp == 0 and party[slot].hp ~= 0 and pid == party[slot].pid then
				http.request("http://joran.fun/db/died.php?pid=" .. pid)
			end
			-- TODO: update level and nickname.
			party[slot].hp = hp
		end
	end
end

-- Applies the update function on a per-frame basis.
gui.register(update)