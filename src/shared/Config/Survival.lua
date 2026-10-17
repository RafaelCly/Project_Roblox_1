--!nonstrict
-- Parámetros de supervivencia del jugador.

local Survival = {
	MAX_HEALTH = 100,
	MAX_HUNGER = 100,
	START_HUNGER = 100,
	HUNGER_DECAY_PER_SECOND = 0.15, -- de 100 a 0 en unos 11 minutos
	STARVE_DAMAGE_PER_SECOND = 1, -- daño por segundo con hambre en 0
	GIVE_MAX_DISTANCE = 12, -- studs para pasar un objeto a un compañero
}

return Survival
