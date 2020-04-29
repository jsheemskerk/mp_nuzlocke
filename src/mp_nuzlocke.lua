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


-- THE SESSION NUMBER OF THIS PLAYTHROUGH
-- Default should be 0
local session = 0

-- Local data storage
local frames = 1
local pokes = {}
local trainer = {
	["badges"] = 0,
	["name"] = "",
	["tid"] = "",
	["location"] = ""
}


-- Returns the ascii value associated with a certain byte.
function as_ascii(byte)
	if byte == 0x00 then return " "
	elseif byte >= 0xA1 and byte <= 0xAA then return string.char(byte - 113)
	elseif byte >= 0xAB and byte <= 0xBA then return chars[byte - 170]
	elseif byte >= 0xBB and byte <= 0xD4 then return string.char(byte - 122)
	elseif byte >= 0xD5 and byte <= 0xEE then return string.char(byte - 116)
	else return ""
	end
end

-- Returns the location associated with a certain byte.
function as_location(byte)
	if byte <= 0x0F then
		return locations[byte + 1]
	elseif byte <= 0x31 then
		return "Route " .. (byte + 85)
	elseif byte <= 0x57 then
		return locations[byte - 33]
	elseif byte >= 0xC5 and byte <= 0xD4 then
		return locations[byte - 142]
	elseif byte == 0xFE or byte == 0xFF then
		return locations[byte - 183]
	else return "Invalid location"
	end
end

-- Returns the current number of badges obtained.
function get_badges()
	local curr_addr = addresses["saveblock1_base"] +
	read_byte(addresses["save_offset_byte"]) +
	save_offsets["badges"]

	local n_badges = get_bits(read_byte(curr_addr), 7, 1)
	for i = 0, 6 do
		n_badges = n_badges + get_bits(read_byte(curr_addr + 1), i, 1)
	end
	return n_badges
end

-- Returns a number of bits from a certain location in a bit string.
function get_bits(bit_str, loc, nbits)
	return bit.rshift(bit_str, loc) % bit.lshift(1, nbits)
end

-- Returns the pokemon data at a certain address.
function get_decrypted_data(address, personality, tid)
	local data = {}
	local data_order = data_orders[(personality % 24) + 1]
	local key = bit.bxor(personality, tid)
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
	local curr_addr = addresses["saveblock2_base"] + read_byte(addresses["save_offset_byte"])
	local time_data = read_dword(curr_addr + save_offsets["time"])
	return 3600 * get_bits(time_data, 0, 16) +
		   60 * get_bits(time_data, 16, 8) +
		   get_bits(time_data, 24, 8)
end

-- Returns the trainer's current location.
function get_location()
	return as_location(read_byte(addresses["location"]))
end

-- Returns the trainer name stored in memory.
function get_tname()
	return get_name(addresses["saveblock2_base"] + read_byte(addresses["save_offset_byte"]), 7)
end


-- Reads a name from a certain address with length n.
function get_name(addr, n)
	local name = ""
	for i = 1, n do
		byte = read_byte(addr + (i - 1))
		if byte ~= 0xFF then name = name .. as_ascii(byte) else break end
	end
	return name
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
		print(nick .. " was not in the database.")
	end
end

-- Posts trainer data to the database.
function post_trainer(tid)
	local trainer_data = [[{
		"tid": ]] .. tid .. [[,
		"tname": "]] .. trainer["name"] .. [[",
		"badges": ]] .. trainer["badges"] .. [[,
		"location": "]] .. trainer["location"] .. [[",
		"session": ]] .. session .. [[
	}]]
	http.request{
		url = "http://www.joran.fun/nuzlocke/db/posttrainer.php",
		method = "POST",
		headers = {
			["Content-Type"] = "application/json",
			["Content-Length"] = trainer_data:len()
		},
		source = ltn12.source.string(trainer_data)
	}
end

-- Update trainer data.
function update_trainer()
	if (trainer["name"] ~= get_tname()) then
		local tid = read_dword(
			addresses["saveblock2_base"] + save_offsets["tid"] +
			read_byte(addresses["save_offset_byte"])
		)
		if tid ~= 0 then
			trainer["name"] = get_tname()
			trainer["tid"] = tid
			trainer["badges"] = get_badges()
			trainer["location"] = get_location()
			post_trainer(tid)
		end
	end
	local n_badges = get_badges()
	if (n_badges ~= 0 and trainer["badges"] ~= n_badges) then
		local tname = trainer["name"]
		trainer["badges"] = get_badges()
		http.request(
			"http://www.joran.fun/nuzlocke/db/updatetrainer.php?tname=" ..
			string.gsub(trainer["name"], " ", "%%20") .. "&tid=" ..
			trainer["tid"] .. '&badges=' .. trainer["badges"]
		)
	elseif (trainer["location"] ~= get_location() or frames >= 3600) then
		local tname = trainer["name"]
		frames = 0
		trainer["location"] = get_location()
		http.request(
			"http://www.joran.fun/nuzlocke/db/updatetrainer.php?tname=" ..
			string.gsub(trainer["name"], " ", "%%20") .. "&tid=" ..
			trainer["tid"] .. "&time=" .. get_ingame_time() ..
			'&loc=' .. string.gsub(trainer["location"], " ", "%%20")
		)
	end
end

-- The script's main function, which updates the database if required.
function update()
	if (frames % 60 == 0) then
		-- Update the trainer data.
		update_trainer()
		for slot = 1, 36 do
			-- Update each pokemon in the party and current box.
			local slot_address = -1
			if slot <= 6 then -- Party
				slot_address = addresses["party"] + (slot - 1) * offsets["slot"]
			else -- Box
				local curr_addr = addresses["boxes_base"] + read_byte(addresses["save_offset_byte"])
				local box_id = read_dword(curr_addr)
				if box_id < 14 then
					slot_address = curr_addr + 4 + box_id * (30 * 80) + (slot - 7) * 80
				else -- Garbage data; pause emulator?
					print(curr_addr, box_id, slot)
					break
				end
			end

			local personality = read_dword(slot_address)

			if personality ~= 0 then

				local tid = read_dword(slot_address + offsets["tid"])
				local data = get_decrypted_data(slot_address, personality, tid)
				local pindex = get_bits(data[1][1], 0, 16)

				local pid = personality
				if pindex == 303 then pid = pid + 1 end -- Shedinja

				local banked = "t"
				if slot <= 6 then banked = "f" end

				if (pokes[pid] == nil or slot <= 6) then
					-- There is a pokemon in the current slot.
					local happiness = get_bits(data[1][3], 8, 8)
					local loc_met = as_location(get_bits(data[4][1], 8, 8))
					local tname = get_name(slot_address + offsets["tname"], 7)
					local hp = 0 
					local lvl = 0
					if slot <= 6 then
						hp = read_word(slot_address + offsets["hp"])
						lvl = read_byte(slot_address + offsets["lvl"])
					end
					local time = get_ingame_time()

					local evs = ''
					for i = 1, 4 do
						evs = evs .. get_bits(data[3][1], (i - 1) * 8, 8) .. ','
					end
					evs = evs .. get_bits(data[3][2], 0, 8) .. ',' .. get_bits(data[3][2], 8, 8)

					local nick = get_name(slot_address + offsets["nick"], 10)
					
					if pokes[pid] == nil then
						-- This pokemon has just been added to the party: post it to the database.
						local nature = natures[(personality % 25) + 1]

						local gender = 0
						local g_threshold = read_byte(
							addresses["poke_info"] + offsets["gender"] + (pindex - 1) * offsets["info"]
						)
						if g_threshold ~= 0xFF then
							if g_threshold == 0xFE then gender = 2
							elseif g_threshold == 0 or get_bits(personality, 0, 8) >= g_threshold then gender = 1
							else gender = 2
							end
						end

						local ivs = get_bits(data[4][2], 0, 5)
						for i = 1, 5 do
							ivs = ivs .. ',' .. get_bits(data[4][2], i * 5, 5)
						end

						local poke_data = [[{
							"pid": ]] .. pid .. [[,
							"tname": "]] .. tname .. [[",
							"tid": ]] .. tid .. [[,
							"pindex": ]] .. pindex .. [[,
							"nick": "]] .. nick .. [[",
							"lvl": ]] .. lvl .. [[,
							"ivs": []] .. ivs .. [[],
							"nature": []] .. nature .. [[],
							"loc_met": "]] .. loc_met .. [[",
							"gender": ]] .. gender .. [[,
							"time_met": "]] .. time .. [[",
							"evs": []] .. evs .. [[],
							"happiness": ]] .. happiness .. [[,
							"banked": "]] .. banked .. [["
						}]]

						if not (loc_met == "Petalburg City" and pindex == 288) then
							-- The pokemon isn't Wally's Zigzagoon.
							post_poke(poke_data, nick)
						end

						pokes[pid] = {
							["pindex"] = pindex, ["hp"] = hp, ["lvl"] = lvl, ["nick"] = nick,
							["banked"] = banked, ["tname"] = tname
						}
					end

					--Pokemon is in party and data was decrypted properly (in the middle of data swap)
					local pindex_key = get_bits(bit.bxor(personality, tid), 0, 16)
					if slot <= 6 and bit.bxor(pindex, pindex_key) ~= pokes[pid].pindex then
						if hp == 0 and pokes[pid].hp ~= 0 then
							-- This pokemon has just fainted: update the associated stats.
							local opp_addr = addresses["opp_party"]
							while (read_word(opp_addr + offsets["hp"]) == 0 and
								   read_dword(opp_addr) ~= 0) do 
								-- Temporary fix: finds the first opponent alive, as their pokemon
								-- stay in the current slot.
								opp_addr = opp_addr + offsets["slot"]
							end
							local opp_personality = read_dword(opp_addr)
							local opp_tid = read_dword(opp_addr + offsets["tid"])
							local opp_data = get_decrypted_data(opp_addr, opp_personality, opp_tid)
							local opp_pindex = get_bits(opp_data[1][1], 0, 16)
							local loc_died, _ = string.gsub(
								as_location(get_bits(opp_data[4][1], 8, 8)), " ", "%%20"
							)
							http.request(
								"http://www.joran.fun/nuzlocke/db/updatepokemon.php?pid=" .. pid ..
								"&loc_died=" .. loc_died .. "&time_died=" .. time .. "&opp=" ..
								opp_pindex .. "&died"
							)
						end

						if pindex ~= pokes[pid].pindex then
							-- The pokemon has evolved: update its stats.
							http.request(
								"http://www.joran.fun/nuzlocke/db/updatepokemon.php?pid=" .. pid ..
								"&lvl=" .. lvl .. "&evs=" .. evs .. "&happiness=" .. happiness ..
								"&pindex=" .. pindex .. "&nick=" .. nick .. "&tname=" ..
								string.gsub(tname, " ", "%%20") .. "&evolved"
							)
						elseif lvl ~= pokes[pid].lvl then
							-- The pokemon has leveled up: update its stats.
							http.request(
								"http://www.joran.fun/nuzlocke/db/updatepokemon.php?pid=" .. pid ..
								"&lvl=" .. lvl .. "&evs=" .. evs .. "&happiness=" .. happiness
							)
						elseif nick ~= pokes[pid].nick then
							-- The pokemon has been renamed.
							http.request(
								"http://www.joran.fun/nuzlocke/db/updatepokemon.php?pid=" .. pid ..
								"&nick=" .. string.gsub(nick, " ", "%%20") .. "&tname=" .. 
								string.gsub(pokes[pid].tname, " ", "%%20") .. "&pindex=" ..
								pindex .. "&rename"
							)
						end

						pokes[pid]["pindex"] = pindex
						pokes[pid]["hp"] = hp
						pokes[pid]["lvl"] = lvl
						pokes[pid]["nick"] = nick
					end
				end
				if pokes[pid]["banked"] ~= banked then
					http.request(
						"http://www.joran.fun/nuzlocke/db/updatepokemon.php?pid=" .. pid ..
						"&banked=" .. banked
					)
					pokes[pid]["banked"] = banked
				end
			end
		end
	end
	frames = frames + 1
end

-- Applies the main function on a per-frame basis.
gui.register(update)
