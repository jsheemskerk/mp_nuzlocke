-- Aliases
local ptr_to_dword = memory.readdwordunsigned

-- Constants
local DWORD_NBYTES = 4

-- Pointers
local start_ptr = 0x20244EC

-- Possible data block orders
local block_orders = {
	{0,1,2,3}, {0,1,3,2}, {0,2,1,3}, {0,3,1,2}, {0,2,3,1}, {0,3,2,1},
	{1,0,2,3}, {1,0,3,2}, {2,0,1,3}, {3,0,1,2}, {2,0,3,1}, {3,0,2,1},
	{1,2,0,3}, {1,3,0,2}, {2,1,0,3}, {3,1,0,2}, {2,3,0,1}, {3,2,0,1},
	{1,2,3,0}, {1,3,2,0}, {2,1,3,0}, {3,1,2,0}, {2,3,1,0}, {3,2,1,0}
}

-- Retrieves a number of bits from a certain location in a bit string.
function get_bits(bit_str, loc, nbits)
	return bit.rshift(bit_str, loc) % bit.lshift(1, nbits)
end

-- Prints IVs for each pokemon in the party.
function print_ivs()
	for slot = 0, 5 do
		slot_ptr = start_ptr + (slot * 25) * DWORD_NBYTES
		personality = ptr_to_dword(slot_ptr)
		trainer_id = ptr_to_dword(slot_ptr + DWORD_NBYTES)
		magic_word = bit.bxor(personality, trainer_id)
		block_order = block_orders[(personality % 24) + 1]

		block_offs = {}
		for i = 1, 4 do
			block_offs[i] = 8 * DWORD_NBYTES + (block_order[i] * 3) * DWORD_NBYTES
		end

		block_00 = ptr_to_dword(slot_ptr + block_offs[1])
		species = get_bits(bit.bxor(block_00, magic_word), 0, 16)

		block_31 = ptr_to_dword(slot_ptr + block_offs[4] + DWORD_NBYTES)
		ivs = get_bits(bit.bxor(block_31, magic_word), 0, 30)

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