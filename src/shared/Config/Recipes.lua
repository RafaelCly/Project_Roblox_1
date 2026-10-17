--!nonstrict
-- Recetas de fabricación (MVP: 5 a 8). inputs: { [idDeItem] = cantidad }.

local Recipes = {
	Bandage = {
		displayName = "Venda",
		inputs = { Cloth = 2 },
		output = { id = "Bandage", count = 1 },
	},
	NoiseTrap = {
		displayName = "Trampa de ruido",
		inputs = { Can = 2, Cloth = 1 },
		output = { id = "NoiseTrap", count = 1 },
	},
}

return Recipes
