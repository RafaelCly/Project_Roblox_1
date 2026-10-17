--!strict
-- Datos de armas. Ajustar aquí el balance sin tocar la lógica.
-- noiseRadius: studs a los que los infectados oyen el arma.

export type WeaponConfig = {
	displayName: string,
	kind: "Melee" | "Firearm",
	damage: number,
	range: number,
	cooldown: number,
	noiseRadius: number,
	durability: number?,
	magazineSize: number?,
	reloadTime: number?,
	ammoId: string?,
}

local Weapons: { [string]: WeaponConfig } = {
	Knife = {
		displayName = "Cuchillo",
		kind = "Melee",
		damage = 20,
		range = 5,
		cooldown = 0.5,
		noiseRadius = 4,
		durability = 120,
	},
	Bat = {
		displayName = "Bate",
		kind = "Melee",
		damage = 35,
		range = 6,
		cooldown = 0.9,
		noiseRadius = 22,
		durability = 60,
	},
	Pistol = {
		displayName = "Pistola",
		kind = "Firearm",
		damage = 45,
		range = 140,
		cooldown = 0.35,
		noiseRadius = 120,
		magazineSize = 12,
		reloadTime = 1.8,
		ammoId = "PistolAmmo",
	},
}

return Weapons
