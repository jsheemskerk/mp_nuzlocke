-- Script which collects the data required for multiplayer Nuzlocke runs.
-- Based on the scripts by https://github.com/EverOddish.

-- Paths
package.path = 'lib/?.lua;' .. package.path
package.cpath = 'lib/?.dll;' .. package.cpath

-- Libraries
http = require "socket.http"
dofile "lib/tables.lua"

-- Aliases
read_dword = memory.readdwordunsigned
read_word = memory.readwordunsigned
read_byte = memory.readbyteunsigned

-- Stores a local representation of the trainer's pokemon.
pokes = {}

-- Returns the ascii value associated with a certain byte.
function get_ascii(byte)
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

-- Returns a number of bits from a certain location in a bit string.
function get_bits(bit_str, loc, nbits)
	return bit.rshift(bit_str, loc) % bit.lshift(1, nbits)
end

-- Returns the pokemon data at a certain address.
function get_decrypted_data(address, pid, tid)
	local data = {}
	local data_order = data_orders[(pid % 24) + 1]
	local key = bit.bxor(pid, tid)
	for i = 1, 4 do
		local block = {}
		for j = 1, 3 do
			block[j] = bit.bxor(
				read_dword(
					address + offsets["data"] +
					data_order[i] * offsets["block"] +
					(j - 1) * offsets["dword"]
				), key
			)
		end
		data[i] = block
	end
	return data
end

-- Returns the current ingame time in seconds.
function get_ingame_time()
	local base = 0x02024a02
	local offset = read_byte(0x2039dd8)
	return 3600 * read_word(base + offset) +
	       60 * read_byte(base + offset + 2) +
		   read_byte(base + offset + 3)
end

-- Returns the location associated with a certain byte.
function get_location(byte)
	if byte <= 0x0F then
		return locations[byte + 1]
	elseif byte <= 0x31 then
		return "Route " .. (byte + 85)
	elseif byte <= 0x57 then
		return locations[byte - 33]
	elseif byte <= 0xD4 then
		return locations[byte - 142]
	else
		return locations[byte - 183]
	end
end

-- Posts pokemon data to the database.
function post_poke(poke_data, nick)
	local response = {}
	http.request{
		url = "http://www.joran.fun/nuzlocke/db/postpokemon.php",
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
		print(nick .. " has been added to the database.")
	end
end

-- Main function, which updates the database if required.
function main()
	for slot = 1, 6 do
		local slot_address = addresses["party"] + (slot - 1) * offsets["slot"]
		local pid = read_dword(slot_address)
		if pid ~= 0 then
			local tid = read_dword(slot_address + offsets["tid"])
			local data = get_decrypted_data(slot_address, pid, tid)
			local pindex = get_bits(data[1][1], 0, 16)

			local nature = natures[(pid % 25) + 1]
			local happiness = get_bits(data[1][3], 8, 8);
			local hp = read_word(slot_address + offsets["hp"])
			local lvl = read_byte(slot_address + offsets["lvl"])

			local evs = {
				get_bits(data[3][1], 0, 8), get_bits(data[3][1], 8, 8),
				get_bits(data[3][1], 16, 8), get_bits(data[3][2], 24, 8),
				get_bits(data[3][2], 0, 8), get_bits(data[3][2], 8, 8)
			}

			local nick = ""
			for i = 1, 10 do
				nick = nick .. get_ascii(read_byte(slot_address + offsets["nick"] + (i - 1)))
			end
			
			if pokes[pid] == nil then
				local loc_met = get_location(get_bits(data[4][1], 8, 8))

				local tname = ""
				for i = 1, 7 do
					tname = tname .. get_ascii(read_byte(slot_address + offsets["tname"] + (i - 1)))
				end

				local gender = 0
				local threshold = read_byte(
					addresses["poke_info"] + offsets["gender"] + (pindex - 1) * offsets["info"]
				)
				if threshold == 0xFE then gender = 2
				elseif threshold == 0 or get_bits(pid, 0, 8) >= threshold then gender = 1
				else gender = 2
				end

				local ivs = {
					get_bits(data[4][2], 0, 5), get_bits(data[4][2], 5, 5),
					get_bits(data[4][2], 10, 5), get_bits(data[4][2], 15, 5),
					get_bits(data[4][2], 20, 5), get_bits(data[4][2], 25, 5)
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
					"speiv": ]] .. ivs[4] .. [[,
					"spaiv": ]] .. ivs[5] .. [[,
					"spdiv": ]] .. ivs[6] .. [[,
					"nature": "]] .. nature .. [[",
					"loc_met": "]] .. loc_met .. [[",
					"time_met": "]] .. get_ingame_time() .. [[",
					"hpev": ]] .. evs[1] .. [[,
					"atkev": ]] .. evs[2] .. [[,
					"defev": ]] .. evs[3] .. [[,
					"speev": ]] .. evs[4] .. [[,
					"spaev": ]] .. evs[5] .. [[,
					"spdev": ]] .. evs[6] .. [[,
					"gender": ]] .. gender .. [[,
					"happiness": ]] .. happiness .. [[
				}]]

				pokes[pid] = {["hp"] = hp, ["lvl"] = lvl, ["nick"] = nick, ["pindex"] = pindex}
				if not (loc_met == "Petalburg City" and pindex == 288) then -- Wally's Zigzagoon
					post_poke(poke_data, nick)
				end
			end
			if hp == 0 and pokes[pid].hp ~= 0 then -- Died
				local opp_pid = read_dword(addresses["opp_party"])
				local opp_tid = read_dword(addresses["opp_party"] + offsets["tid"])
				local opp_data = get_decrypted_data(addresses["opp_party"], opp_pid, opp_tid)
				local loc_died, _ = string.gsub(
					get_location(get_bits(opp_data[4][1], 8, 8)), " ", "%%20"
				)
				http.request(
					"http://www.joran.fun/nuzlocke/db/update.php?pid=" .. pid .. "&loc_died=" ..
					loc_died .. "&time_died=" .. get_ingame_time() .. "&died"
				)
			end
			if lvl ~= pokes[pid].lvl then -- Level up, also updates EVs and happiness
				http.request(
					"http://www.joran.fun/nuzlocke/db/update.php?pid=" .. pid .. "&lvl=" .. lvl ..
					"&hpev=" .. evs[1] .. "&atkev=" .. evs[2] .. "&defev=" .. evs[3] .. "&speev=" ..
					evs[4] .. "&spaev=" .. evs[5] .. "&spdev=" .. evs[6] .. "&happiness=" .. happiness
				)
			end
			if pindex ~= pokes[pid].pindex or nick ~= pokes[pid].nick then -- Evolution, name change
				http.request(
					"http://www.joran.fun/nuzlocke/db/update.php?pid=" .. pid .. "&nick=" ..nick ..
					"&pindex=" .. pindex
				)
			end
			pokes[pid] = {["hp"] = hp, ["lvl"] = lvl, ["nick"] = nick, ["pindex"] = pindex}
		end
	end
end

-- Applies the main function on a per-frame basis.
gui.register(main)