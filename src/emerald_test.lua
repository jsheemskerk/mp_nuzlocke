-- Aliases
local ptr_to_dword = memory.readdwordunsigned

-- Constants
local DWORD_SIZE = 32
local DWORD_PTR_SIZE = 4

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
function get_bits(bit_str, loc, n_bits)
	return bit.rshift(bit_str, loc) % bit.lshift(1, n_bits)
end

-- Prints IVs for each pokemon in the party.
function print_ivs()
	for slot = 0, 5 do
		poke_ptr = start_ptr + 100 * slot
		personality = ptr_to_dword(poke_ptr)
		trainer_id = ptr_to_dword(poke_ptr + DWORD_PTR_SIZE)
		magic_word = bit.bxor(personality, trainer_id)
		block_order = block_orders[(personality % 24) + 1]

		blocks_off = DWORD_PTR_SIZE * 8
		block_0_off = blocks_off + block_order[1] * (3 * DWORD_PTR_SIZE)
		block_1_off = blocks_off + block_order[2] * (3 * DWORD_PTR_SIZE)
		block_2_off = blocks_off + block_order[3] * (3 * DWORD_PTR_SIZE)
		block_3_off = blocks_off + block_order[4] * (3 * DWORD_PTR_SIZE)

		block_0_dword_0 = bit.bxor(ptr_to_dword(poke_ptr + block_0_off), magic_word)
		species = get_bits(block_0_dword_0, 0, 16)

		block_3_dword_1 = bit.bxor(ptr_to_dword(poke_ptr + block_3_off + DWORD_PTR_SIZE), magic_word)
		ivs = get_bits(block_3_dword_1, 0, 30)

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