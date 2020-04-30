-- Storage for functions which might be useful in the future.

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

-- Prints the current ingame time to the console.
function print_ingame_time()
	local base = 0x02024a02
	local offset = read_byte(0x2039dd8)
	print("Hours: " .. read_word(base + offset))
	print("Minutes: " .. read_byte(base + offset + 2))
	print("Seconds: " .. read_byte(base + offset + 3))
end

-- Prints when a key is pressed.
function print_keypress()
	if input.get()["Q"] then
		print_ingame_time()
	end
end