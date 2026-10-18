--!nonstrict
-- Prueba de estrés del servidor (semana 2, día 5). Solo corre dentro de Roblox Studio.
-- Cómo usarla: con el juego en marcha, en la barra de comandos del Servidor escribe
--   workspace:SetAttribute("DevStress", 30)
-- Aparecen esa cantidad de infectados alrededor del primer jugador y se mide en el
-- servidor cuántos FPS mantiene en tres fases: reposo, alerta por ruido y combate.
-- Resultado en Output: busca "[Stress]". No corre sola; no afecta a SelfTest.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

if not RunService:IsStudio() then
	return
end

local ZombieService = require(script.Parent.Services.ZombieService)
local NoiseService = require(script.Parent.Services.NoiseService)
local RunConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.Run)

local TARGET_FPS = 30 -- criterio de la semana 2: el servidor no baja de 30 FPS
local SETTLE_SECONDS = 3
local PHASE_SECONDS = { Reposo = 10, Alerta = 15, Combate = 15 }
local SPAWN_RING = { 25, 45 } -- distancia mínima y máxima al jugador
local NOISE_RADIUS = 120 -- igual que la pistola

local running = false

local function log(message: string)
	print(`[Stress] {message}`)
end

local function firstPlayerRoot(): BasePart?
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid and humanoid.Health > 0 then
			return root
		end
	end
	return nil
end

-- Mide cuadros del servidor durante `seconds`. Devuelve los FPS de cada segundo.
local function measure(seconds: number)
	local perSecond = {}
	local frames, windowStart = 0, os.clock()
	local started = windowStart
	local worstFrame = 0
	local last = windowStart
	while os.clock() - started < seconds do
		RunService.Heartbeat:Wait()
		local now = os.clock()
		worstFrame = math.max(worstFrame, now - last)
		last = now
		frames += 1
		if now - windowStart >= 1 then
			table.insert(perSecond, frames / (now - windowStart))
			frames, windowStart = 0, now
		end
	end
	return perSecond, worstFrame
end

local function summarize(perSecond: { number }, worstFrame: number)
	local minFps, sum = math.huge, 0
	for _, fps in perSecond do
		minFps = math.min(minFps, fps)
		sum += fps
	end
	local avg = #perSecond > 0 and sum / #perSecond or 0
	return avg, (#perSecond > 0 and minFps or 0), worstFrame
end

local function stateCounts()
	local counts = {}
	for _, model in workspace.Zombies:GetChildren() do
		local state = ZombieService:GetState(model)
		if state and not ZombieService:IsDead(model) then
			counts[state] = (counts[state] or 0) + 1
		end
	end
	local parts = {}
	for state, count in counts do
		table.insert(parts, `{state}={count}`)
	end
	table.sort(parts)
	return table.concat(parts, " ")
end

local function runPhase(name: string, setup, failures: { string })
	if setup then
		setup()
	end
	local perSecond, worstFrame = measure(PHASE_SECONDS[name])
	local avg, minFps, worst = summarize(perSecond, worstFrame)
	log(`{name}: FPS promedio {string.format("%.1f", avg)}, mínimo en 1 s {string.format("%.1f", minFps)}, cuadro más lento {string.format("%.0f", worst * 1000)} ms, vivos {ZombieService:CountActive()}`)
	log(`{name}: estados {stateCounts()}`)
	if minFps < TARGET_FPS then
		table.insert(failures, `{name}: mínimo {string.format("%.1f", minFps)} FPS (< {TARGET_FPS})`)
	end
end

local function spawnRing(root: BasePart, amount: number): number
	local rng = Random.new()
	local spawned = 0
	for i = 1, amount do
		local angle = (i / amount) * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local distance = rng:NextNumber(SPAWN_RING[1], SPAWN_RING[2])
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
		if ZombieService:Spawn("Walker", root.Position + offset) then
			spawned += 1
		end
	end
	return spawned
end

local function killAll()
	for _, model in workspace.Zombies:GetChildren() do
		if ZombieService:GetRecord(model) then
			ZombieService:Damage(model, 99999, nil)
		end
	end
end

local function runStress(amount: number)
	if running then
		warn("[Stress] Ya hay una prueba en curso")
		return
	end
	running = true
	local root = firstPlayerRoot()
	if not root then
		warn("[Stress] FAIL no hay ningún jugador vivo. Espera a que aparezca tu personaje.")
		running = false
		return
	end
	amount = math.min(amount, RunConfig.MAX_ACTIVE_ZOMBIES)
	log(`---- Prueba de estrés: {amount} infectados, jugadores {#Players:GetPlayers()}`)

	local spawned = spawnRing(root, amount)
	log(`Aparecieron {spawned}/{amount}`)
	local failures = {}
	if spawned < amount then
		table.insert(failures, `solo aparecieron {spawned} de {amount}`)
	end
	task.wait(SETTLE_SECONDS)

	runPhase("Reposo", nil, failures)
	runPhase("Alerta", function()
		local current = firstPlayerRoot() or root
		NoiseService:Emit(current.Position, NOISE_RADIUS, nil)
	end, failures)
	runPhase("Combate", function()
		-- Disparo repetido: mantiene a todos alerta mientras llegan al jugador y atacan.
		task.spawn(function()
			for _ = 1, 5 do
				local current = firstPlayerRoot()
				if current then
					NoiseService:Emit(current.Position, NOISE_RADIUS, nil)
				end
				task.wait(2)
			end
		end)
	end, failures)

	killAll()
	task.wait(4) -- los cadáveres tardan en desaparecer
	log(`Tras limpiar quedan {ZombieService:CountActive()} infectados vivos`)

	if #failures == 0 then
		log(`RESULTADO: PASS ({amount} infectados, el servidor se mantuvo sobre {TARGET_FPS} FPS)`)
	else
		for _, reason in failures do
			warn(`[Stress] FAIL {reason}`)
		end
		warn(`[Stress] RESULTADO: FAIL ({#failures} problemas)`)
	end
	running = false
end

workspace:GetAttributeChangedSignal("DevStress"):Connect(function()
	local amount = workspace:GetAttribute("DevStress")
	if typeof(amount) ~= "number" or amount < 1 then
		return
	end
	workspace:SetAttribute("DevStress", nil)
	task.spawn(runStress, math.floor(amount))
end)

log("Listo. Escribe workspace:SetAttribute(\"DevStress\", 30) en la barra de comandos del servidor.")
