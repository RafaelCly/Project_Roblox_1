--!strict
-- Datos de infectados. Visión en cono (grados y studs), oído por eventos de ruido.

export type ZombieConfig = {
	displayName: string,
	health: number,
	walkSpeed: number,
	chaseSpeed: number,
	damage: number,
	attackCooldown: number,
	sightRange: number,
	sightAngle: number,
	hearingMultiplier: number,
	budgetCost: number,
}

local Zombies: { [string]: ZombieConfig } = {
	Walker = {
		displayName = "Caminante",
		health = 100,
		walkSpeed = 4,
		chaseSpeed = 8,
		damage = 10,
		attackCooldown = 1.2,
		sightRange = 45,
		sightAngle = 110,
		hearingMultiplier = 1,
		budgetCost = 1,
	},
	Runner = {
		displayName = "Corredor",
		health = 60,
		walkSpeed = 6,
		chaseSpeed = 15,
		damage = 8,
		attackCooldown = 0.8,
		sightRange = 55,
		sightAngle = 120,
		hearingMultiplier = 1.2,
		budgetCost = 2,
	},
	Brute = {
		displayName = "Bruto",
		health = 400,
		walkSpeed = 3,
		chaseSpeed = 7,
		damage = 28,
		attackCooldown = 1.8,
		sightRange = 40,
		sightAngle = 90,
		hearingMultiplier = 0.8,
		budgetCost = 6,
	},
}

return Zombies
