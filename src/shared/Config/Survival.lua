--!nonstrict
-- Parámetros de supervivencia del jugador.

local Survival = {
	MAX_HEALTH = 100,
	MAX_HUNGER = 100,
	START_HUNGER = 100,
	HUNGER_DECAY_PER_SECOND = 0.15, -- de 100 a 0 en unos 11 minutos
	STARVE_DAMAGE_PER_SECOND = 1, -- daño por segundo con hambre en 0
	GIVE_MAX_DISTANCE = 12, -- studs para pasar un objeto a un compañero

	-- Caído y levantar. El tiempo para ser levantado y los levantamientos por jugador
	-- están en Config/Run (DOWNED_SECONDS, REVIVES_PER_PLAYER).
	DOWNED_WALK_SPEED = 4,
	REVIVE_HOLD_SECONDS = 3, -- lo que hay que mantener pulsado "Levantar"
	REVIVE_DISTANCE = 6, -- studs entre el compañero y el caído
	REVIVE_DISTANCE_TOLERANCE = 1.5, -- margen del servidor por el retraso de la red
	REVIVE_HEALTH = 30,
}

return Survival
