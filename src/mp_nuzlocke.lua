-- Script which retrieves data required for multiplayer Nuzlocke runs.
-- Based on the scripts by https://github.com/EverOddish.

-- Aliases
read_dword = memory.readdwordunsigned
read_byte = memory.readbyteunsigned

-- Constants
DWORD_NBYTES = 4

-- History
past_input = {}

-- Retrieves a number of bits from a certain location in a bit string.
function get_bits(bit_str, loc, nbits)
	return bit.rshift(bit_str, loc) % bit.lshift(1, nbits)
end

-- Retrieves the data for a certain slot in the correct block order.
function get_slot_data(slot_ptr, block_offs, magic_word)
	local data = {}
	for i = 1, 4 do
		local block = {}
		for j = 1, 3 do
			block[j] = bit.bxor(
				read_dword(slot_ptr + block_offs[i] + (j - 1) * DWORD_NBYTES), magic_word
			)
		end
		data[i] = block
	end
	return data
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

-- Retrieves the data for each pokemon in the party.
function get_party_data()
	local start_ptr = 0x20244EC
	local block_orders = {
		{0,1,2,3}, {0,1,3,2}, {0,2,1,3}, {0,3,1,2}, {0,2,3,1}, {0,3,2,1},
		{1,0,2,3}, {1,0,3,2}, {2,0,1,3}, {3,0,1,2}, {2,0,3,1}, {3,0,2,1},
		{1,2,0,3}, {1,3,0,2}, {2,1,0,3}, {3,1,0,2}, {2,3,0,1}, {3,2,0,1},
		{1,2,3,0}, {1,3,2,0}, {2,1,3,0}, {3,1,2,0}, {2,3,1,0}, {3,2,1,0}
	}
	local charset = {[0xBB] = "A", [0xFF] = ""}
	local input = input.get()
	for slot = 0, 5 do
		local slot_ptr = start_ptr + (slot * 25) * DWORD_NBYTES
		local personality = read_dword(slot_ptr)
		local trainer_id = read_dword(slot_ptr + DWORD_NBYTES)
		local nature = personality % 25
		local magic_word = bit.bxor(personality, trainer_id)

		local block_order = block_orders[(personality % 24) + 1]
		local block_offs = {}
		for i = 1, 4 do
			block_offs[i] = 8 * DWORD_NBYTES + (block_order[i] * 3) * DWORD_NBYTES
		end

		local slot_data = get_slot_data(slot_ptr, block_offs, magic_word)
		local id = get_bits(slot_data[1][1], 0, 16)
		local exp = get_bits(slot_data[1][2], 0, 16)
		local move_ids = {
			get_bits(slot_data[2][1], 0, 16), get_bits(slot_data[2][1], 16, 16),
			get_bits(slot_data[2][2], 0, 16), get_bits(slot_data[2][2], 16, 16),
		}
		local pp = {
			get_bits(slot_data[2][3], 0, 8), get_bits(slot_data[2][3], 8, 8),
			get_bits(slot_data[2][3], 16, 8), get_bits(slot_data[2][3], 24, 8),
		}
		local evs = {
			get_bits(slot_data[3][1], 0, 8), get_bits(slot_data[3][1], 8, 8),
			get_bits(slot_data[3][1], 16, 8), get_bits(slot_data[3][1], 24, 8),
			get_bits(slot_data[3][2], 0, 8), get_bits(slot_data[3][2], 8, 16)
		}
		local ivs = {
			get_bits(slot_data[4][2], 0, 5), get_bits(slot_data[4][2], 5, 5),
			get_bits(slot_data[4][2], 10, 5), get_bits(slot_data[4][2], 15, 5),
			get_bits(slot_data[4][2], 20, 5), get_bits(slot_data[4][2], 25, 5),
		}

		if id ~= 0 then
			if input["Q"] and past_input["Q"] == nil then 
				local str = "Pokemon: " .. id .. ". IVs: "
				for i = 1, 5 do
					str = str .. ivs[i] .. "/"
				end
				print(str .. ivs[6])
			elseif input["W"] and past_input["W"] == nil then
				for i = 1, 4 do
					print("Slot " .. slot .. " Block " .. i)
					for j = 1, 3 do
						print(j .. ": " .. as_bits(slot_data[i][j], 8))
					end
				end
			elseif input["E"] and past_input["E"] == nil then
				local trainer_name = ""
				local name_ptr = slot_ptr + 5 * DWORD_NBYTES
				for i = 1, 7 do
					trainer_name = trainer_name .. charset[read_byte(name_ptr + (i - 1))]
				end
				print(trainer_name)
			end
		end
	end
	past_input = input
end

gui.register(get_party_data)