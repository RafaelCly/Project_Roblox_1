--!nonstrict
-- Tablas de botín por tipo de edificio.
-- chance: probabilidad de que un punto de botín tenga algo.
-- entries: weight = peso relativo, count = { mínimo, máximo }.

local Loot = {
	House = {
		chance = 0.75,
		entries = {
			{ id = "CannedFood", weight = 30, count = { 1, 2 } },
			{ id = "Cloth", weight = 25, count = { 1, 3 } },
			{ id = "Can", weight = 15, count = { 1, 2 } },
			{ id = "Bandage", weight = 10, count = { 1, 1 } },
			{ id = "PistolAmmo", weight = 8, count = { 4, 10 } },
			{ id = "Knife", weight = 5, count = { 1, 1 } },
			{ id = "Bat", weight = 5, count = { 1, 1 } },
			{ id = "Pistol", weight = 2, count = { 1, 1 } },
		},
	},
}

return Loot
