--!nonstrict
-- Parámetros de la IA de infectados (comunes a todos los tipos).
-- Lo propio de cada tipo (velocidad, visión, daño) está en Config/Zombies.

local ZombieAI = {
	STEP_SECONDS = 0.2, -- cada cuánto piensa cada infectado
	ATTACK_RANGE = 4.5, -- studs para poder golpear
	REACHED_DISTANCE = 3, -- a cuántos studs se considera llegado a un punto

	IDLE_SECONDS = { 2, 5 }, -- espera mínima y máxima antes de volver a deambular
	WANDER_RADIUS = 20, -- hasta dónde se aleja de su punto de origen
	WANDER_TIMEOUT = 8, -- si no llega a su destino, se rinde y espera
	INVESTIGATE_TIMEOUT = 10, -- tiempo máximo yendo a un ruido o último punto visto
	INVESTIGATE_SPEED_MULTIPLIER = 1.5, -- sobre su velocidad de caminar
	LOSE_SECONDS = 2, -- tiempo sin ver al objetivo antes de dejar de perseguir

	-- Marcador del día 2: ve a quien esté a menos de esta distancia, sin cono ni paredes.
	-- El día 3 lo reemplaza por visión real (cono, rayo) y oído.
	PROXIMITY_SENSE_RANGE = 16,

	PATH_RECOMPUTE_SECONDS = 1, -- cada cuánto recalcula una ruta con obstáculos
	PATH_WAYPOINT_DISTANCE = 3, -- a cuántos studs pasa al siguiente punto de la ruta
}

return ZombieAI
