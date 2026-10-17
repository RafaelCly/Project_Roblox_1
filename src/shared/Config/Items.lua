--!nonstrict
-- Catálogo de objetos. Para añadir un objeto basta con una entrada aquí.
-- kind: Weapon | Ammo | Food | Heal | Material | Trap

export type ItemConfig = {
	displayName: string,
	kind: string,
	stackMax: number,
	hunger: number?,
	heal: number?,
	weaponId: string?,
}

local Items: { [string]: ItemConfig } = {
	Knife = { displayName = "Cuchillo", kind = "Weapon", stackMax = 1, weaponId = "Knife" },
	Bat = { displayName = "Bate", kind = "Weapon", stackMax = 1, weaponId = "Bat" },
	Pistol = { displayName = "Pistola", kind = "Weapon", stackMax = 1, weaponId = "Pistol" },
	PistolAmmo = { displayName = "Munición 9mm", kind = "Ammo", stackMax = 30 },
	CannedFood = { displayName = "Comida enlatada", kind = "Food", stackMax = 4, hunger = 35 },
	Bandage = { displayName = "Venda", kind = "Heal", stackMax = 4, heal = 30 },
	Cloth = { displayName = "Tela", kind = "Material", stackMax = 10 },
	Can = { displayName = "Lata vacía", kind = "Material", stackMax = 6 },
	NoiseTrap = { displayName = "Trampa de ruido", kind = "Trap", stackMax = 2 },
}

return Items
