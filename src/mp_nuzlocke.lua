-- Script which collects the data required for MP Nuzlocke runs.
-- Heemskerk, J. S. & Teunisse, J. J. (2020)

-- Paths
package.cpath = 'lib/?.dll;' .. package.cpath
package.path = 'lib/?.lua;' .. package.path

-- Libraries
dofile "lib/tables.lua"
http = require "socket.http"

-- Aliases
read_byte = memory.readbyteunsigned
read_word = memory.readwordunsigned
read_dword = memory.readdwordunsigned

-- Current session: should be 0 by default.
local session = 0

-- Variables which store data between updates.
local frames = 1
local pokes = {}
local trainer = {
	["tname"] = ""
}

-- Returns the ascii character associated with a certain byte.
function as_ascii(byte)
	if byte == 0x00 then return " "
	elseif byte >= 0xA1 and byte <= 0xAA then return string.char(byte - 113)
	elseif byte >= 0xAB and byte <= 0xBA then return chars[byte - 170]
	elseif byte >= 0xBB and byte <= 0xD4 then return string.char(byte - 122)
	elseif byte >= 0xD5 and byte <= 0xEE then return string.char(byte - 116)
	else return "_invalid_ascii_"
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

-- Implements the conditional (ternary) operator.
function cop(cond, t, f)
	if cond then return t else return f end
end

-- Returns the number of set bits in a bit string. (Kernighan's algorithm)
function count_set_bits(bstr)
	local n_bits = 0
	while bstr ~= 0 do
		bstr = bit.band(bstr, bstr - 1)
		n_bits = n_bits + 1
	end
	return n_bits
end

-- Returns the number of badges obtained thus far.
function get_badges()
	local addr = addresses["saveblock1_base"] +
				 read_byte(addresses["save_offset_byte"]) +
				 offsets.sb1["badges"]
	local badge_data = bit.band(read_word(addr), masks["badges"])
	return count_set_bits(badge_data)
end

-- Returns basic data about the pokemon in a certain slot.
function get_base_data(slot_addr)
	local pers = read_dword(slot_addr)
	local tid = read_dword(slot_addr + offsets.poke["tid"])
	local key = bit.bxor(pers, tid)
	local data = get_decrypted_data(slot_addr, pers, key)
	local pindex = get_bits(data[1][1], 0, 16)

	return {
		["pers"] = pers, ["tid"] = tid, ["key"] = key,
		["data"] = data, ["pindex"] = pindex
	}
end

-- Returns a number of bits from a certain location in a bit string.
function get_bits(bstr, loc, nbits)
	return bit.rshift(bstr, loc) % bit.lshift(1, nbits)
end

-- Returns the pokemon data at a certain address.
function get_decrypted_data(addr, pers, key)
	local data = {}
	local data_order = data_orders[(pers % #data_orders) + 1]
	for i = 1, 4 do
		local block = {}
		for j = 1, 3 do
			block[j] = bit.bxor(
				read_dword(
					addr + offsets.poke["data"] +
					data_order[i] * data_sizes["block"] +
					(j - 1) * data_sizes["dword"]
				), key
			)
		end
		data[i] = block
	end
	return data
end

-- Returns the EVs stored in the data.
function get_evs(data)
	local evs = ''
	for i = 1, 4 do
		evs = evs .. get_bits(data[3][1], (i - 1) * 8, 8) .. ','
	end
	return evs .. get_bits(data[3][2], 0, 8) .. ',' .. get_bits(data[3][2], 8, 8)
end

-- Returns a gender based upon the personality and pindex.
function get_gender(pers, pindex)
	local threshold = read_byte(
		addresses["base_stats"] +
		offsets.base_stats["gender"] +
		(pindex - 1) * data_sizes["base_stats"]
	)
	if threshold ~= 0xFF then
		if threshold == 0xFE then return 2
		elseif threshold == 0 or get_bits(pers, 0, 8) >= threshold then return 1
		else return 2
		end
	end
	return 0
end

-- Returns the current ingame time in seconds.
function get_ingame_time()
	local addr = addresses["saveblock2_base"] +
				 read_byte(addresses["save_offset_byte"]) +
				 offsets.sb2["time"]
	local time_data = read_dword(addr)
	return 3600 * get_bits(time_data, 0, 16) +
		   60 * get_bits(time_data, 16, 8) +
		   get_bits(time_data, 24, 8)
end

-- Returns the IVs stored in the data.
function get_ivs(data)
	local ivs = get_bits(data[4][2], 0, 5)
	for i = 1, 5 do
		ivs = ivs .. ',' .. get_bits(data[4][2], i * 5, 5)
	end
	return ivs
end

-- Returns the current league progression.
function get_league_prog()
	local addr = addresses["saveblock1_base"] +
				 read_byte(addresses["save_offset_byte"]) +
				 offsets.sb1["badges"]
	local champion_data = bit.band(read_word(addr), masks["champion"])
	if count_set_bits(champion_data) == 1 then
		-- The champion has been beaten.
		return const["n_league_members"]
	else
		addr = addresses["saveblock1_base"] +
			   read_byte(addresses["save_offset_byte"]) +
			   offsets.sb1["elite4"]
		local elite4_data = bit.band(read_byte(addr), masks["elite4"])
		return count_set_bits(elite4_data)
	end
end

-- Returns the name stored at a certain address with maximum length n.
function get_name(addr, n)
	local name = ""
	for i = 0, (n - 1) do
		byte = read_byte(addr + i)
		if byte ~= 0xFF then name = name .. as_ascii(byte) else break end
	end
	return name
end

-- Returns the address which holds the data for the current slot.
function get_slot_address(slot)
	if slot <= const["party_size"] then
		-- The slot concerns a party member.
		return addresses["party"] + (slot - 1) * data_sizes["poke"]
	else
		-- The slot concerns a boxed pokemon.
		local addr = addresses["boxes_base"] + read_byte(addresses["save_offset_byte"])
		local box_id = read_dword(addr)
		if box_id < const["n_boxes"] then
			-- The box ID is valid.
			return addr + offsets.boxes["pokes"] +
				   box_id * const["box_size"] * data_sizes["boxed_poke"] +
				   (slot - 7) * data_sizes["boxed_poke"]
		else
			-- The box ID is invalid.
			return -1
		end
	end
end

-- Posts pokemon data to the database.
function post_poke(slot_addr, banked, base, pid)
	local evs = get_evs(base["data"])
	local gender = get_gender(base["pers"], base["pindex"])
	local happiness = get_bits(base["data"][1][3], 8, 8)
	local hp = cop(banked == "f", read_byte(slot_addr + offsets.poke["hp"]), 0)
	local ivs = get_ivs(base["data"])
	local loc_met = as_location(get_bits(base["data"][4][1], 8, 8))
	local lvl = cop(banked == "f", read_byte(slot_addr + offsets.poke["lvl"]), 0)
	local nature = natures[(base["pers"] % 25) + 1]
	local nick = get_name(slot_addr + offsets.poke["nick"], 10)
	local tname = get_name(slot_addr + offsets.poke["tname"], 7)
	local time_met = get_ingame_time()

	local poke_data = [[{
		"banked": "]] .. banked .. [[",
		"evs": []] .. evs .. [[],
		"gender": ]] .. gender .. [[,
		"happiness": ]] .. happiness .. [[,
		"ivs": []] .. ivs .. [[],
		"loc_met": "]] .. loc_met .. [[",
		"lvl": ]] .. lvl .. [[,
		"nature": []] .. nature .. [[],
		"nick": "]] .. nick .. [[",
		"pindex": ]] .. base["pindex"] .. [[,
		"pid": ]] .. pid .. [[,
		"tid": ]] .. base["tid"] .. [[,
		"time_met": "]] .. time_met .. [["
	}]]

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
		print(nick .. " was known to the database.")
	else
		print(nick .. " was unknown to the database.")
	end

	pokes[pid] = {
		["banked"] = banked, ["hp"] = hp, ["lvl"] = lvl, ["nick"] = nick,
		["pindex"] = base["pindex"], ["tname"] = tname
	}
end

-- Posts trainer data to the database.
function post_trainer()
	local trainer_data = [[{
		"badges": ]] .. trainer["badges"] .. [[,
		"league": ]] .. trainer["league"] .. [[,
		"location": "]] .. trainer["location"] .. [[",
		"time": ]] .. get_ingame_time() .. [[,
		"tid": ]] .. trainer["tid"] .. [[,
		"tname": "]] .. trainer["tname"] .. [[",
		"session": ]] .. session .. [[
	}]]

	local response = {}
	http.request{
		url = "http://www.joran.fun/nuzlocke/db/posttrainer.php",
		method = "POST",
		headers = {
			["Content-Type"] = "application/json",
			["Content-Length"] = trainer_data:len()
		},
		source = ltn12.source.string(trainer_data),
		sink = ltn12.sink.table(response)
	}
	if string.match(table.concat(response), "duplicate key") then
		print("Trainer " .. trainer["tname"] .. " was known to the database.")
	else
		print("Trainer " .. trainer["tname"] .. " was unknown to the database.")
	end
end

-- Updates a pokemon in the current box.
function update_box(boxes_addr, box_id, slot)
	local slot_addr = -1

	if box_id < const["n_boxes"] then
		-- Box ID is valid.
		slot_addr = boxes_addr + offsets.boxes["pokes"] +
					box_id * const["box_size"] * data_sizes["boxed_poke"] +
					(slot - 1) * data_sizes["boxed_poke"]
	end

	if slot_addr ~= -1 and read_dword(slot_addr) ~= 0 then
		-- Slot address contains a pokemon.
		local banked = "t"
		local base = get_base_data(slot_addr)
		local pid = cop(base["pindex"] == const["shedinja_pindex"], base["pers"] + 1, base["pers"])

		if pokes[pid] == nil then
			-- Pokemon is unknown locally.
			post_poke(slot_addr, banked, base, pid)
		elseif pokes[pid]["banked"] ~= banked then
			-- Pokemon was just banked.
			pokes[pid]["banked"] = banked
			http.request(
				"http://www.joran.fun/nuzlocke/db/updatepokemon.php?pid=" ..
				pid .. "&banked=" .. banked
			)
		end
	end
end

-- Updates a pokemon in the party.
function update_party(slot)
	local slot_addr = addresses["party"] + (slot - 1) * data_sizes["poke"]

	if read_dword(slot_addr) ~= 0 then
		-- Slot address contains a pokemon.
		local banked = "f"
		local base = get_base_data(slot_addr)
		local pid = cop(base["pindex"] == const["shedinja_pindex"], base["pers"] + 1, base["pers"])

		if pokes[pid] == nil then
			-- Pokemon is unknown locally.
			local loc_met = as_location(get_bits(base["data"][4][1], 8, 8))

			if (base["tid"] ~= const["steven_tid"] and not (loc_met == "Petalburg City" and
				base["pindex"] == const["zigzagoon_pindex"])) then
				post_poke(slot_addr, banked, base, pid)
			end
		elseif bit.bxor(base["pindex"], get_bits(base["key"], 0, 16)) ~= pokes[pid]["pindex"] then
			-- Pokemon data is known locally and not corrupted, check for updates.
			-- A maximum of one update is applied to avoid ingame lagspikes.
			local hp = read_byte(slot_addr + offsets.poke["hp"])
			local lvl = read_byte(slot_addr + offsets.poke["lvl"])
			local nick = get_name(slot_addr + offsets.poke["nick"], 10)

			local url = "http://www.joran.fun/nuzlocke/db/updatepokemon.php?pid=" .. pid

			if hp == 0 and pokes[pid]["hp"] ~= 0 then
				-- The pokemon just fainted.
				local opp_addr = addresses["opp_party"]
				while (read_word(opp_addr + offsets.poke["hp"]) == 0 and
					   read_dword(opp_addr) ~= 0) do
					opp_addr = opp_addr + data_sizes["poke"]
				end
				local opp_base = get_base_data(opp_addr)
				local loc_died = as_location(get_bits(opp_base["data"][4][1], 8, 8))
				local time_died = get_ingame_time()

				pokes[pid]["hp"] = hp
				http.request(
					url .. "&opp_pindex=" .. opp_base["pindex"] .."&loc_died=" ..
					string.gsub(loc_died, " ", "%%20") .. "&time_died=" .. time_died
				)
			elseif (base["pindex"] ~= pokes[pid]["pindex"] or
					lvl ~= pokes[pid]["lvl"] or
					nick ~= pokes[pid]["nick"]) then
				-- One of the dynamic stats has changed.
				local evs = get_evs(base["data"])
				local happiness = get_bits(base["data"][1][3], 8, 8)
				local status = ""
				if base["pindex"] ~= pokes[pid]["pindex"] then status = "&evolved"
				elseif nick ~= pokes[pid]["nick"] then status = "&rename"
				end

				pokes[pid]["pindex"] = base["pindex"]
				pokes[pid]["nick"] = nick
				pokes[pid]["lvl"] = lvl
				http.request(
					url .. "&pindex=" .. base["pindex"] .. "&lvl=" .. lvl .. "&nick=" .. 
					string.gsub(nick, " ", "%%20") .. "&evs=" .. evs .. "&happiness=" ..
					happiness .. status
				)
			elseif banked ~= pokes[pid]["banked"] then
				-- The pokemon was just added to the party.
				pokes[pid]["banked"] = banked
				http.request(url .. "&banked=" .. banked)
			end
		end
	end
end

-- Updates the trainer data.
function update_trainer()
	local badges = get_badges()
	local league = get_league_prog()
	local location = as_location(read_byte(addresses["location"]))
	local tname = get_name(addresses["saveblock2_base"] + read_byte(addresses["save_offset_byte"]), 7)

	if tname ~= "" and trainer["tname"] ~= tname then
		-- Trainer is unknown locally.
		local tid = read_dword(
			addresses["saveblock2_base"] +
			read_byte(addresses["save_offset_byte"]) +
			offsets.sb2["tid"]
		)
		if tid ~= 0 then
			-- Trainer has a valid TID.
			trainer = {
				["badges"] = badges, ["league"] = league, ["location"] = location,
				["tid"] = tid, ["tname"] = tname
			}
			post_trainer()
		end
	else
		-- Trainer is known locally, check for updates.
		-- A maximum of one update is applied to avoid ingame lagspikes.
		local url = "http://www.joran.fun/nuzlocke/db/updatetrainer.php?tid=" .. trainer["tid"]

		if badges > trainer["badges"] then
			-- The number of badges has increased.
			trainer["badges"] = badges
			http.request(url .. "&badges=" .. badges)
		elseif league > trainer["league"] then
			-- The number of league members beaten has increased.
			trainer["league"] = league
			if league ~= 5 then 
				http.request(url .. "&league=" .. league)
			else
				http.request(url .. "&league=" .. league .. "&clear_time=" .. get_ingame_time())
			end
		elseif location ~= trainer["location"] then
			-- The trainer's overworld location has changed.
			trainer["location"] = location
			http.request(url .. "&loc=" .. string.gsub(location, " ", "%%20"))
		elseif frames >= const["fps"] * 60 then
			-- Update ingame time every minute and reset individual party updates.
			frames = 0
			http.request(url .. "&time=" .. get_ingame_time())
		end
	end
end

-- The script's main function, which updates the data if required.
function update()
	if frames % const["fps"] == 0 then
		-- Update the data every second.
		update_trainer()

		for slot = 1, const["party_size"] do
			update_party(slot)
		end

		local boxes_addr = addresses["boxes_base"] + read_byte(addresses["save_offset_byte"])
		local box_id = read_dword(boxes_addr)
		for slot = 1, const["box_size"] do
			update_box(boxes_addr, box_id, slot)
		end
	end
	frames = frames + 1
end

-- Applies the main function on a per-frame basis.
gui.register(update)
