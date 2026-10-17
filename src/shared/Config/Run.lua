--!strict
-- Parámetros de una partida (30 minutos máximo).

local Run = {
	MAX_PLAYERS = 4,
	MIN_PLAYERS_TO_START = 2,
	LOBBY_WAIT_SECONDS = 45, -- espera tras alcanzar el mínimo de jugadores
	RUN_DURATION_SECONDS = 30 * 60,

	REVIVES_PER_PLAYER = 1,
	DOWNED_SECONDS = 45, -- tiempo para que un compañero te levante

	MAX_ACTIVE_ZOMBIES = 50,

	-- Oleadas: segundo de inicio y presupuesto base de dificultad.
	Waves = {
		{ startsAt = 8 * 60, budget = 20 },
		{ startsAt = 17 * 60, budget = 45 },
		{ startsAt = 25 * 60, budget = 80 }, -- final, en la puerta del búnker
	},
	BUDGET_PER_EXTRA_PLAYER = 0.25, -- +25% de presupuesto por jugador sobre el primero

	BUNKER_DOOR_SECONDS = 90,
	BUNKER_PARTS_REQUIRED = 3,
}

return Run
