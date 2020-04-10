data = [["Poochyena", 3, 21, 22, 7, 29, 4, 29], ["Torchic", 8, 0, 5, 31, 22, 6, 27], ["Zigzagoon", 3, 9, 26, 13, 13, 5, 26], ["Poochyena", 3, 8, 28, 27, 18, 23, 5]]

for row in data:
	s = "{:11s}Lv. {} [{}".format(row[0], row[1], row[2])
	for i in row[3:7]:
		s += "/{}".format(i)
	print(s + "]")