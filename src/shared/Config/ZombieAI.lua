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

	-- Visión: el cono y el alcance salen de Config/Zombies (sightAngle, sightRange).
	AWARE_RANGE = 5, -- a esta distancia nota a alguien aunque esté fuera del cono (con línea de visión)
	ALERT_RANGE_MULTIPLIER = 1.25, -- perseguir amplía el alcance; además ve alrededor (sin cono)
	EYE_HEIGHT = 1.5, -- altura de los ojos sobre el centro del infectado
	TARGET_HEIGHT = 1, -- punto del jugador al que mira el rayo, sobre su centro

	PATH_RECOMPUTE_SECONDS = 1, -- cada cuánto recalcula una ruta con obstáculos
	PATH_WAYPOINT_DISTANCE = 3, -- a cuántos studs pasa al siguiente punto de la ruta
}

return ZombieAI
