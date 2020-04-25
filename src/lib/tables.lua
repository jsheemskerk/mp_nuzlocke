-- Tables required for the MP Nuzlocke script.

addresses = {
	["location"] = 0x203732C,
	["party"] = 0x20244EC,
	["opp_party"] = 0x02024744,
	["poke_info"] = 0x083203E8,
	["saveblock1_base"] = 0x20259A0,
	["saveblock2_base"] = 0x20249F4,
	["boxes_base"] = 0x20297A8,
	["save_offset_byte"] = 0x2039DD8
}
chars = {"!", "?", ".", "-", "", ".", "\"", "\"", "'", "'", "M", "F", "", ",", "", "/"}
data_orders = {
	{0,1,2,3}, {0,1,3,2}, {0,2,1,3}, {0,3,1,2}, {0,2,3,1}, {0,3,2,1},
	{1,0,2,3}, {1,0,3,2}, {2,0,1,3}, {3,0,1,2}, {2,0,3,1}, {3,0,2,1},
	{1,2,0,3}, {1,3,0,2}, {2,1,0,3}, {3,1,0,2}, {2,3,0,1}, {3,2,0,1},
	{1,2,3,0}, {1,3,2,0}, {2,1,3,0}, {3,1,2,0}, {2,3,1,0}, {3,2,1,0}
}
locations = {
	"Littleroot Town", "Oldale Town", "Dewford Town", "Lavaridge Town", "Fallarbor Town", 
	"Verdanturf Town", "Pacifidlog Town", "Petalburg City", "Slateport City", "Mauville City", 
	"Rustboro City", "Fortree City", "Lilycove City", "Mossdeep City", "Sootopolis City", 
	"Ever Grande City", "Underwater (Route 124)", "Underwater (Route 126)", "Underwater (Route 127)",
	"Underwater (Route 128)", "Underwater (Sootopolis City)", "Granite Cave", "Mt. Chimney",
	"Safari Zone", "Battle Frontier", "Petalburg Woods", "Rusturf Tunnel", "Abandoned Ship",
	"New Mauville", "Meteor Falls", "Meteor Falls", "Mt. Pyre", "Hideout", "Shoal Cave",
	"Seafloor Cavern", "Underwater (Seafloor Cavern)", "Victory Road", "Mirage Island",
	"Cave of Origin", "Southern Island", "Fiery Path", "Fiery Path", "Jagged Pass", "Jagged Pass",
	"Sealed Chamber", "Underwater (Route 134)", "Scorched Slab", "Island Cave", "Desert Ruins",
	"Ancient Tomb", "Inside of Truck", "Sky Pillar", "Secret Base", "Ferry", "Aqua Hideout",
	"Magma Hideout", "Mirage Tower", "Birth Island", "Faraway Island", "Artisan Cave", "Marine Cave",
	"Underwater (Marine Cave)", "Terra Cave", "Underwater (Route 105)", "Underwater (Route 125)",
	"Underwater (Route 129)", "Desert Underpass", "Altering Cave", "Navel Rock", "Trainer Hill",
	"Ingame Trade", "Fateful Encounter"
}
natures = {
	"\"Hardy\"", "\"Lonely\",0,1", "\"Brave\",0,2", "\"Adamant\",0,3", "\"Naughty\",0,4",
	"\"Bold\",1,0", "\"Docile\"", "\"Relaxed\",1,2", "\"Impish\",1,3", "\"Lax\",1,4",
	"\"Timid\",2,0", "\"Hasty\",2,1", "\"Serious\"", "\"Jolly\",2,3", "\"Naive\",2,4",
	"\"Modest\",3,0", "\"Mild\",3,1", "\"Quiet\",3,2", "\"Bashful\"", "\"Rash\",3,4",
	"\"Calm\",4,0", "\"Gentle\",4,1", "\"Sassy\",4,2", "\"Careful\",4,3", "\"Quirky\""
}
offsets = {
	["dword"] = 4,
	["tid"] = 4,
	["nick"] = 8,
	["block"] = 12,
	["gender"] = 16,
	["tname"] = 20,
	["info"] = 28,
	["data"] = 32,
	["lvl"] = 84,
	["hp"] = 86,
	["slot"] = 100
}

save_offsets = {
	-- Save block 1:
	-- This is flag offset (0x1270) plus badge flag byte offset (0x10c) in one.
	["badges"] = 4988,
	
	-- Save block 2:
	["time"] = 14,
	["tid"] = 10
}
