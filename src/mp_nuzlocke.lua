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

-- Local data storage
local frames = 1
local pokes = {}
local trainer = {
	["badges"] = 0,
	["name"] = "",
	["location"] = ""
}


-- Returns the ascii value associated with a certain byte.
function as_ascii(byte)
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
function as_location(byte)
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

-- TODO: Returns the pokemon which are currently boxed.
function get_boxes()
	local curr_addr = addresses["boxes_base"] + read_byte(addresses["save_offset_byte"])
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
	local curr_addr = addresses["saveblock2_base"] + save_offsets["time"] + read_byte(addresses["save_offset_byte"])
	local time_data = read_dword(curr_addr)
	return 3600 * get_bits(time_data, 0, 16) +
		   60 * get_bits(time_data, 16, 8) +
		   get_bits(time_data, 24, 8)
end

-- Returns the trainer's current location.
function get_location()
	return as_location(read_byte(addresses["location"]))
end

-- Returns the trainer name found at a certain address.
function get_tname()
	local curr_addr = addresses["saveblock2_base"] + read_byte(addresses["save_offset_byte"])
	return get_name(curr_addr, 7)
end


-- Reads a name from a certain address and length n.
function get_name(addr, n)
	name = ""
	for i = 1, n do
		name = name .. as_ascii(read_byte(addr + (i - 1)))
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
		print(nick .. " has been added to the database.")
	end
end

-- Posts trainer data to the database.
function post_trainer()
	local tid = read_dword(
		addresses["saveblock2_base"] + save_offsets["tid"] + read_byte(addresses["save_offset_byte"])
	)
	if tid ~= 0 then
		local trainer_data = [[{
			"tid": ]] .. tid .. [[,
			"tname": "]] .. trainer["name"] .. [["
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
end

-- Update trainer data.
function update_trainer()
	if (trainer["name"] ~= get_tname()) then
		trainer["name"] = get_tname()
		post_trainer()
	end
	if (trainer["badges"] ~= get_badges()) then
		local badges = get_badges()
		local tname = trainer["name"]
		trainer["badges"] = badges
		response = http.request(
			"http://www.joran.fun/nuzlocke/db/updatetrainer.php?tname=" .. tname ..
			'&badges=' .. trainer["badges"]
		)
		print(response)
		print(trainer["badges"])
	elseif (trainer["location"] ~= location or frames >= 3600) then
		local tname = trainer["name"]
		local location = get_location()
		frames = 0
		trainer["location"] = location
		http.request(
			"http://www.joran.fun/nuzlocke/db/updatetrainer.php?tname=" .. tname .."&time=" ..
			get_ingame_time() .. '&loc=' .. string.gsub(trainer["location"], " ", "%%20")
		)
	end
end

-- The script's main function, which updates the database if required.
function update()
	if (input.get()["Q"]) then
		str = ""
		for i = 0, 100 do
			str = str .. string.format("%.8x", read_dword(
				addresses["boxes_base"] + read_byte(addresses["save_offset_byte"]) + i * 4
			)) .. ' '
		end
		print(str)
	end
	if (frames % 60 == 0) then
		-- Update the trainer data.
		update_trainer()
		for slot = 1, 36 do
			-- Update each pokemon in the party.
			local slot_address = -1
			if slot <= 6 then -- Party
				slot_address = addresses["party"] + (slot - 1) * offsets["slot"]
			else -- Box
				curr_addr = addresses["boxes_base"] + read_byte(addresses["save_offset_byte"])
				slot_address = curr_addr + 4 + read_dword(curr_addr) * (30 * 80) + (slot - 7) * 80
			end
			local pid = read_dword(slot_address)
			if pid ~= 0 and (pokes[pid] == nil or slot <= 6) then
				-- There is a pokemon in the current slot.
				local tid = read_dword(slot_address + offsets["tid"])
				local data = get_decrypted_data(slot_address, pid, tid)
				local pindex = get_bits(data[1][1], 0, 16)
				local happiness = get_bits(data[1][3], 8, 8);
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
					local nature = natures[(pid % 25) + 1]
					local loc_met = as_location(get_bits(data[4][1], 8, 8))
					local tname = get_name(slot_address + offsets["tname"], 7)

					local gender = 0
					local g_threshold = read_byte(
						addresses["poke_info"] + offsets["gender"] + (pindex - 1) * offsets["info"]
					)
					if g_threshold ~= 0xFF then
						if g_threshold == 0xFE then gender = 2
						elseif g_threshold == 0 or get_bits(pid, 0, 8) >= g_threshold then gender = 1
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
						"pindex": ]] .. pindex .. [[,
						"nick": "]] .. nick .. [[",
						"lvl": ]] .. lvl .. [[,
						"ivs": []] .. ivs .. [[],
						"nature": []] .. nature .. [[],
						"loc_met": "]] .. loc_met .. [[",
						"gender": ]] .. gender .. [[,
						"time_met": "]] .. time .. [[",
						"evs": []] .. evs .. [[],
						"happiness": ]] .. happiness .. [[
					}]]

					if not (loc_met == "Petalburg City" and pindex == 288) then
						-- The pokemon isn't Wally's Zigzagoon.
						post_poke(poke_data, nick)
					end

					pokes[pid] = {["pindex"] = pindex, ["hp"] = hp, ["lvl"] = lvl, ["nick"] = nick}
				end

				if slot <= 6 then
					if hp == 0 and pokes[pid].hp ~= 0 then
						-- This pokemon has just fainted: update the associated stats.
						local opp_pid = read_dword(addresses["opp_party"])
						local opp_tid = read_dword(addresses["opp_party"] + offsets["tid"])
						local opp_data = get_decrypted_data(addresses["opp_party"], opp_pid, opp_tid)
						local opp_pindex = get_bits(opp_data[1][1], 0, 16)
						local loc_died, _ = string.gsub(
							as_location(get_bits(opp_data[4][1], 8, 8)), " ", "%%20"
						)
						http.request(
							"http://www.joran.fun/nuzlocke/db/updatepokemon.php?pid=" .. pid .. "&loc_died=" ..
							loc_died .. "&time_died=" .. time .. "&opp=" .. opp_pindex .. "&died"
						)
					end

					if pindex ~= pokes[pid].pindex then
						-- Pokemon has evolved, send all stats.
						http.request(
							"http://www.joran.fun/nuzlocke/db/updatepokemon.php?pid=" .. pid .. "&lvl=" .. lvl ..
							"&evs=" .. evs .. "&happiness=" .. happiness .. "&nick=" .. nick ..
							"&pindex=" .. pindex
						)
					elseif lvl ~= pokes[pid].lvl or nick ~= pokes[pid].nick then
						-- Either the level or nickname has changed: update all dynamic stats.
						http.request(
							"http://www.joran.fun/nuzlocke/db/updatepokemon.php?pid=" .. pid .. "&lvl=" .. lvl ..
							"&evs=" .. evs .. "&happiness=" .. happiness .. "&nick=" .. nick
						)
					end

					pokes[pid] = {["pindex"] = pindex, ["hp"] = hp, ["lvl"] = lvl, ["nick"] = nick}
				end
			end
		end
	end
	frames = frames + 1
end

-- Applies the main function on a per-frame basis.
gui.register(update)
