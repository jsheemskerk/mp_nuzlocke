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

-- History features
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


-- Helper/debug function that prints out the current time to the console.
function print_ingame_time()
	local base = 0x02024a02
	local offset = read_byte(0x2039dd8)
	print("Hours: " .. read_word(base + offset))
	print("Minutes: " .. read_byte(base + offset + 2))
	print("Seconds: " .. read_byte(base + offset + 3))
end

-- Returns the current ingame time in seconds.
function igt_seconds()
	local base = 0x02024a02
	local offset = read_byte(0x2039dd8)
	return 3600 * read_word(base + offset) +
	       60 * read_byte(base + offset + 2) +
		   read_byte(base + offset + 3)
end

-- Represents a dword as a MSB-first bit string, divided into blocks.
function as_bits(dword, block_len)
	local bits = ""
	local blocks = math.floor(32 / block_len)
	local str_size = blocks * block_len
	for i = 0, (blocks - 1) do
		for j = 0, (block_len - 1) do
			bits = bits .. bit.rshift(dword, (str_size - 1) - (i * block_len + j)) % 2
		end
		if i ~= (blocks - 1) then
			bits = bits .. " "
		end
	end
	return bits
end

-- Retrieves a number of bits from a certain location in a bit string.
function get_bits(bit_str, loc, nbits)
	return bit.rshift(bit_str, loc) % bit.lshift(1, nbits)
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

-- Returns the location associated with a certain byte.
function to_location(byte)
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

-- Updates the database if required.
prev = input.get()
function update()
	curr = input.get()
	if curr["Q"] and not prev["Q"] then
		print_ingame_time()
	end
	prev = input.get()

	local party_addr = 0x20244EC
	local opp_addr = 0x02024744
	local basestats_addr = 0x083203E8  --general pokemon info, includes more than just base stats
	
	local opp_pid = read_dword(opp_addr)
	local opp_tid = read_dword(opp_addr + offsets["tid"])
	local opp_data = decrypt_data(opp_addr, opp_pid, opp_tid)
	
	for slot = 1, 6 do
		local slot_addr = party_addr + (slot - 1) * offsets["slot"]
		local pid = read_dword(slot_addr)
		if pid ~= 0 then
			local tid = read_dword(slot_addr + offsets["tid"])
			local data = decrypt_data(slot_addr, pid, tid)
			local pindex = get_bits(data[1][1], 0, 16)
			local hp = read_word(slot_addr + offsets["hp"])
			local lvl = read_byte(slot_addr + offsets["lvl"])
			
			--gender
			local genderbyte = read_byte(slot_addr)
			local basegenderbyte = read_byte(basestats_addr + 16 + (pindex - 1) * 28)
			local gender = 0
			if (basegenderbyte == 0xFF) then gender = 0 --genderless
			elseif (basegenderbyte == 0xFE) then gender = 2 --female
			elseif (genderbyte >= basegenderbyte) then gender = 1 --male
			else gender = 2
			end


			local nick = ""
			for i = 1, 10 do
				nick = nick .. to_ascii(read_byte(slot_addr + offsets["nick"] + (i - 1)))
			end
			
			local nature = natures[(pid % 25) + 1]
			if pokes[pid] == nil then
				local tname = ""
				for i = 1, 7 do
					tname = tname .. to_ascii(read_byte(slot_addr + offsets["tname"] + (i - 1)))
				end
				local ivs = {
					get_bits(data[4][2], 0, 5), get_bits(data[4][2], 5, 5),
					get_bits(data[4][2], 10, 5), get_bits(data[4][2], 20, 5),
					get_bits(data[4][2], 25, 5), get_bits(data[4][2], 15, 5)
				}

				local evs = {
					get_bits(data[3][1], 0, 8),
					get_bits(data[3][1], 8, 8),
					get_bits(data[3][1], 16, 8),
					get_bits(data[3][1], 24, 8),
					get_bits(data[3][2], 0, 8),
					get_bits(data[3][2], 8, 8)
				}

				local happiness = get_bits(data[1][3], 8, 8);

				local loc_met = to_location(get_bits(data[4][1], 8, 8))

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
					"speiv": ]] .. ivs[6] .. [[,
					"nature": "]] .. nature .. [[",
					"loc_met": "]] .. loc_met .. [[",
					"time_met": "]] .. igt_seconds() .. [[",
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
				local loc_died, _ = string.gsub(to_location(get_bits(opp_data[4][1], 8, 8)), " ", "%%20")
				local response = {}
				http.request{
					url = "http://www.joran.fun/nuzlocke/db/update.php?pid=" .. pid .. "&loc_died=" .. loc_died .. "&time_died=" .. igt_seconds() .. "&died" ,
					sink = ltn12.sink.table(response)
				}
				print("Died_response: " .. table.concat(response))
			end
			if lvl ~= pokes[pid].lvl then -- Level up
				http.request("http://www.joran.fun/nuzlocke/db/update.php?pid=" .. pid .. "&lvl=" .. lvl)
			end
			if nick ~= pokes[pid].nick then -- Name change
				http.request("http://www.joran.fun/nuzlocke/db/update.php?pid=" .. pid .. "&nick=" .. nick)
			end
			if pindex ~= pokes[pid].pindex then -- Evolution
				http.request("http://www.joran.fun/nuzlocke/db/update.php?pid=" .. pid .. "&pindex=" .. pindex)
				http.request("http://www.joran.fun/nuzlocke/db/update.php?pid=" .. pid .. "&nick=" .. nick)
			end
			pokes[pid] = {["hp"] = hp, ["lvl"] = lvl, ["nick"] = nick, ["pindex"] = pindex}
		end
	end
end

-- Applies the update function on a per-frame basis.
gui.register(update)
