
-- simple print
print("simple print")

-- formatted print
pi = math.pi
io.write("print formatted " , pi, "\n")

--conditionals
numb = 0
if numb < 5 then
	io.write("ye\n")
elseif (numb > 5 ) and (numb < 10) then
	io.write("adsasd\n")
else
	io.write("bignum\n")
end

-- ternary op does not exit
--bignum = numb > 20 ? true : false
bignum = numb > 20 and true or false

--loops
i=0
while (i < 3) do 
	io.write(i)
	i = i+1
end
for i=0, 3, 1 do
	io.write(i)
end

--run on gui update
function test() 
	print("hoi")
end
--gui.register(test)


--to run: lua helloworld.lua
