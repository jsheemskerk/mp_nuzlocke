-- Aliases
local bit_xor = bit.bxor
local mem_uint32 = memory.readdwordunsigned

-- Pointers
local stats_ptr = 0x20244EC

-- Tables
local ivs_tbl = {4,3,4,3,2,2, 4,3,4,3,2,2, 4,3,4,3,2,2, 1,1,1,1,1,1}
local species_tbl = {1,1,1,1,1,1, 2,2,3,4,3,4, 2,2,3,4,3,4, 2,2,3,4,3,4}

-- Retrieves a number of bits from a certain location in a bit string.
function get_bits(bit_str, loc, n_bits)
	return bit.rshift(bit_str, loc) % bit.lshift(1, n_bits)
end

-- Prints IVs for each pokemon in the party.
function print_ivs()
	for slot = 0, 5 do
		start = stats_ptr + 100 * slot
		personality = mem_uint32(start)
		trainer_id = mem_uint32(start + 4)
		offsets_loc = personality % 24
		magic_word = bit_xor(personality, trainer_id)

		species_offset = (species_tbl[offsets_loc + 1] - 1) * 12
		species_loc = bit_xor(mem_uint32(start + 32 + species_offset), magic_word)
		species = get_bits(species_loc, 0, 16)

		ivs_offset = (ivs_tbl[offsets_loc + 1] - 1) * 12
		ivs = bit_xor(mem_uint32(start + 32 + ivs_offset + 4), magic_word)

		if input.get()["Q"] and species ~= 0 then
			str = "Pokemon: " .. species .. ". IVs: "
			for ivnr = 0, 4 do
				str = str .. get_bits(ivs, ivnr * 5, 5) .. "/" 
			end
			print(str .. get_bits(ivs, 25, 5))
		end
	end
end
gui.register(print_ivs)