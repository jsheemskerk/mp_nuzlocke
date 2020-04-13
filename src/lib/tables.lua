-- Tables required for the MP Nuzlocke script.

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
	"Hardy","Lonely","Brave","Adamant","Naughty",
	"Bold","Docile","Relaxed","Impish","Lax",
	"Timid","Hasty","Serious","Jolly","Naive",
	"Modest","Mild","Quiet","Bashful","Rash",
	"Calm","Gentle","Sassy","Careful","Quirky"
}
offsets = {
	["dword"] = 4,
	["tid"] = 4,
	["nick"] = 8,
	["block"] = 12,
	["tname"] = 20,
	["data"] = 32,
	["lvl"] = 84,
	["hp"] = 86,
	["slot"] = 100
}