--!nonstrict
-- Decisión pura de la máquina de estados del infectado (sin física ni Instances).
-- Estados: Idle, Wander, Investigate, Chase, Attack.
--
-- ctx:
--   hasTarget        bool    hay un jugador al alcance de sus sentidos ahora mismo
--   distance         number  distancia al objetivo (solo importa si hasTarget)
--   attackRange      number
--   timeInState      number  segundos en el estado actual
--   idleTime         number  cuánto debe esperar en Idle
--   wanderTimeout    number
--   investigateTimeout number
--   reachedPoint     bool    llegó al punto de deambular o investigar
--   targetLostFor    number  segundos sin ver al objetivo
--   loseSeconds      number

local ZombieBrain = {}

ZombieBrain.States = {
	Idle = "Idle",
	Wander = "Wander",
	Investigate = "Investigate",
	Chase = "Chase",
	Attack = "Attack",
}

function ZombieBrain.next(state: string, ctx): string
	if state == "Chase" then
		if ctx.hasTarget then
			return ctx.distance <= ctx.attackRange and "Attack" or "Chase"
		end
		if ctx.targetLostFor >= ctx.loseSeconds then
			return "Investigate"
		end
		return "Chase"
	end

	if state == "Attack" then
		if not ctx.hasTarget then
			return ctx.targetLostFor >= ctx.loseSeconds and "Investigate" or "Chase"
		end
		-- Un margen (30%) evita que cambie de Chase a Attack en cada paso al borde del rango.
		return ctx.distance > ctx.attackRange * 1.3 and "Chase" or "Attack"
	end

	-- Idle, Wander e Investigate: ver a alguien lo interrumpe todo.
	if ctx.hasTarget then
		return ctx.distance <= ctx.attackRange and "Attack" or "Chase"
	end

	if state == "Idle" then
		return ctx.timeInState >= ctx.idleTime and "Wander" or "Idle"
	end
	if state == "Wander" then
		if ctx.reachedPoint or ctx.timeInState >= ctx.wanderTimeout then
			return "Idle"
		end
		return "Wander"
	end
	if state == "Investigate" then
		if ctx.reachedPoint or ctx.timeInState >= ctx.investigateTimeout then
			return "Idle"
		end
		return "Investigate"
	end

	return "Idle"
end

return ZombieBrain
