--!nonstrict
-- ZombieService
-- Aparición, vida, muerte, movimiento y ataque de infectados. Dueño: Rafael.
-- Contrato con Axel (docs/plan-semana-2.md):
--   ZombieService:Damage(model, amount, source) -> true si lo mató
--   ZombieService:FromInstance(instance)        -> modelo del infectado o nil
-- Estados: Idle, Wander, Investigate, Chase, Attack (decisión en shared/Util/ZombieBrain).
-- Sentidos: visión con cono y rayo contra paredes (shared/Util/Vision) y oído de los
-- ruidos que emite NoiseService.

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ZombieConfig = require(Shared.Config.Zombies)
local RunConfig = require(Shared.Config.Run)
local AI = require(Shared.Config.ZombieAI)
local Brain = require(Shared.Util.ZombieBrain)
local Vision = require(Shared.Util.Vision)

local ZombieService = {}

local CORPSE_SECONDS = 3
local SKIN_COLOR = Color3.fromRGB(105, 135, 85)
local CLOTH_COLOR = Color3.fromRGB(70, 70, 75)

local zombies = {} -- [Model] = registro
local activeCount = 0
local zombieFolder = nil
local template = nil
local templateLoading = false
local rng = Random.new()

-- Modelo base ---------------------------------------------------------------

-- Crea (una sola vez) el personaje R15 verdoso que se clona para cada infectado.
local function getTemplate()
	if template then
		return template
	end
	if templateLoading then
		while templateLoading do
			task.wait(0.1)
		end
		return template
	end

	templateLoading = true
	local ok, result = pcall(function()
		local description = Instance.new("HumanoidDescription")
		description.HeadColor = SKIN_COLOR
		description.LeftArmColor = SKIN_COLOR
		description.RightArmColor = SKIN_COLOR
		description.TorsoColor = CLOTH_COLOR
		description.LeftLegColor = CLOTH_COLOR
		description.RightLegColor = CLOTH_COLOR
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	templateLoading = false

	if ok and result then
		template = result
	else
		warn(`[ZombieService] No se pudo crear el modelo base: {tostring(result)}`)
	end
	return template
end

-- Utilidades de mundo -------------------------------------------------------

-- Parámetros de rayo que ignoran infectados, jugadores y objetos del suelo.
local function rayParams()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { zombieFolder, workspace:FindFirstChild("Pickups") }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	return params
end

-- Suelo bajo una posición, para que no aparezcan dentro de una pared o en el aire.
local function groundPosition(position: Vector3): Vector3
	local result = workspace:Raycast(position + Vector3.new(0, 50, 0), Vector3.new(0, -200, 0), rayParams())
	local y = result and result.Position.Y or position.Y
	return Vector3.new(position.X, y, position.Z)
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- Daño y estado de jugadores. SurvivalService es de Axel: si todavía no tiene
-- Damage o IsDowned (semana 2), se usa un reemplazo simple.
local function damagePlayer(player: Player, amount: number, source: Instance?)
	local ok, Survival = pcall(require, script.Parent.SurvivalService)
	if ok and type(Survival.Damage) == "function" then
		Survival:Damage(player, amount, source)
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid:TakeDamage(amount)
	end
end

local function isDowned(player: Player): boolean
	local ok, Survival = pcall(require, script.Parent.SurvivalService)
	if ok and type(Survival.IsDowned) == "function" then
		return Survival:IsDowned(player) == true
	end
	return false
end

-- Sentidos ------------------------------------------------------------------

-- Visión: dentro del cono (o alrededor si ya está alerta), dentro del alcance y sin
-- pared en medio. Un infectado alerta (persiguiendo o atacando) ve más lejos y en 360°.
local function canSee(record, targetPosition: Vector3, distance: number): boolean
	local alerted = record.state == "Chase" or record.state == "Attack"
	local range = record.config.sightRange * (alerted and AI.ALERT_RANGE_MULTIPLIER or 1)
	if distance > range then
		return false
	end

	local angle = alerted and 360 or record.config.sightAngle
	local origin = record.root.Position
	if not Vision.inFieldOfView(origin, record.root.CFrame.LookVector, targetPosition, range, angle, AI.AWARE_RANGE) then
		return false
	end

	-- Una pared (o cualquier cosa sólida) entre los ojos y el jugador bloquea la vista.
	local eye = origin + Vector3.new(0, AI.EYE_HEIGHT, 0)
	local aim = targetPosition + Vector3.new(0, AI.TARGET_HEIGHT, 0)
	return workspace:Raycast(eye, aim - eye, rayParams()) == nil
end

-- Devuelve el jugador al que el infectado prestará atención, su distancia y posición.
-- Prefiere jugadores no caídos y, entre ellos, el más cercano.
local function senseTarget(record)
	local origin = record.root.Position
	local best, bestDistance, bestPosition, bestDowned = nil, math.huge, nil, true

	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 then
			local distance = (root.Position - origin).Magnitude
			if canSee(record, root.Position, distance) then
				local downed = isDowned(player)
				local better = (bestDowned and not downed) or (downed == bestDowned and distance < bestDistance)
				if better then
					best, bestDistance, bestPosition, bestDowned = player, distance, root.Position, downed
				end
			end
		end
	end

	return best, bestDistance, bestPosition
end

-- Movimiento ----------------------------------------------------------------

-- Camina hacia un punto. En línea recta si no hay obstáculos; si los hay, sigue una ruta.
local function moveTowards(record, goal: Vector3, now: number)
	local humanoid = record.humanoid
	local origin = record.root.Position
	local eye = Vector3.new(0, 1.5, 0)

	local blocked = workspace:Raycast(origin + eye, (goal + eye) - (origin + eye), rayParams()) ~= nil
	if not blocked then
		record.waypoints = nil
		humanoid:MoveTo(goal)
		return
	end

	if not record.waypoints or now >= record.nextPathAt then
		record.nextPathAt = now + AI.PATH_RECOMPUTE_SECONDS
		local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = false })
		local ok = pcall(function()
			path:ComputeAsync(origin, goal)
		end)
		if ok and path.Status == Enum.PathStatus.Success then
			record.waypoints = path:GetWaypoints()
			record.waypointIndex = 2 -- el 1 es donde ya está
		else
			record.waypoints = nil
		end
	end

	local waypoint = record.waypoints and record.waypoints[record.waypointIndex]
	if waypoint then
		humanoid:MoveTo(waypoint.Position)
		if flatDistance(origin, waypoint.Position) < AI.PATH_WAYPOINT_DISTANCE then
			record.waypointIndex += 1
		end
	else
		humanoid:MoveTo(goal)
	end
end

local function stopMoving(record)
	record.humanoid:MoveTo(record.root.Position)
	record.waypoints = nil
end

-- Máquina de estados --------------------------------------------------------

local function enterState(record, newState: string, now: number)
	local config = record.config
	record.state = newState
	record.stateSince = now
	record.waypoints = nil

	if newState == "Idle" then
		record.idleTime = rng:NextNumber(AI.IDLE_SECONDS[1], AI.IDLE_SECONDS[2])
		record.humanoid.WalkSpeed = config.walkSpeed
		stopMoving(record)
	elseif newState == "Wander" then
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(AI.WANDER_RADIUS * 0.4, AI.WANDER_RADIUS)
		record.wanderGoal = record.home + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		record.humanoid.WalkSpeed = config.walkSpeed
	elseif newState == "Investigate" then
		record.humanoid.WalkSpeed = config.walkSpeed * AI.INVESTIGATE_SPEED_MULTIPLIER
	else -- Chase y Attack
		record.humanoid.WalkSpeed = config.chaseSpeed
	end
end

local function step(record, now: number)
	if record.dead then
		return
	end

	local target, distance, targetPosition = senseTarget(record)
	if target then
		record.target = target
		record.lastSeenPosition = targetPosition
		record.lastSeenAt = now
	end

	local goal = nil
	if record.state == "Wander" then
		goal = record.wanderGoal
	elseif record.state == "Investigate" then
		goal = record.investigatePoint
	end

	local nextState = Brain.next(record.state, {
		hasTarget = target ~= nil,
		distance = distance,
		attackRange = AI.ATTACK_RANGE,
		timeInState = now - record.stateSince,
		idleTime = record.idleTime,
		wanderTimeout = AI.WANDER_TIMEOUT,
		investigateTimeout = AI.INVESTIGATE_TIMEOUT,
		reachedPoint = goal ~= nil and flatDistance(record.root.Position, goal) < AI.REACHED_DISTANCE,
		targetLostFor = record.lastSeenAt and (now - record.lastSeenAt) or math.huge,
		loseSeconds = AI.LOSE_SECONDS,
	})

	if nextState ~= record.state then
		-- Al dejar de perseguir, va al último sitio donde vio al jugador.
		if nextState == "Investigate" and (record.state == "Chase" or record.state == "Attack") then
			record.investigatePoint = record.lastSeenPosition or record.root.Position
		end
		enterState(record, nextState, now)
	end

	-- Acción del estado actual.
	if record.state == "Wander" then
		moveTowards(record, record.wanderGoal, now)
	elseif record.state == "Investigate" then
		moveTowards(record, record.investigatePoint, now)
	elseif record.state == "Chase" then
		moveTowards(record, targetPosition or record.lastSeenPosition or record.root.Position, now)
	elseif record.state == "Attack" and target then
		stopMoving(record)
		local root = record.root
		root.CFrame = CFrame.lookAt(root.Position, Vector3.new(targetPosition.X, root.Position.Y, targetPosition.Z))
		if now - record.lastAttackAt >= record.config.attackCooldown then
			record.lastAttackAt = now
			damagePlayer(target, record.config.damage, record.model)
		end
	end
end

-- Muerte --------------------------------------------------------------------

local function kill(record)
	if record.dead then
		return
	end
	record.dead = true
	activeCount -= 1
	record.humanoid.Health = 0
	task.delay(CORPSE_SECONDS, function()
		zombies[record.model] = nil
		record.model:Destroy()
	end)
end

-- API pública ---------------------------------------------------------------

-- Aparece un infectado. Devuelve el modelo, o nil si se alcanzó el límite
-- o no se pudo crear el modelo base. typeId debe existir en Config/Zombies.
function ZombieService:Spawn(typeId: string, position: Vector3)
	local config = ZombieConfig[typeId]
	assert(config, `Tipo de infectado desconocido: {tostring(typeId)}`)

	if activeCount >= RunConfig.MAX_ACTIVE_ZOMBIES then
		return nil
	end
	local base = getTemplate()
	if not base then
		return nil
	end
	-- getTemplate puede esperar: volver a comprobar el límite.
	if activeCount >= RunConfig.MAX_ACTIVE_ZOMBIES then
		return nil
	end

	local model = base:Clone()
	model.Name = `Zombie_{typeId}`
	model:SetAttribute("IsZombie", true)
	model:SetAttribute("ZombieType", typeId)

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		model:Destroy()
		return nil
	end
	humanoid.MaxHealth = config.health
	humanoid.Health = config.health
	humanoid.WalkSpeed = config.walkSpeed
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff

	local spawnPosition = groundPosition(position)
	local now = os.clock()
	local record = {
		model = model,
		humanoid = humanoid,
		root = root,
		config = config,
		typeId = typeId,
		dead = false,
		busy = false,
		lastAttacker = nil,
		home = spawnPosition,
		state = "Idle",
		stateSince = now,
		idleTime = rng:NextNumber(AI.IDLE_SECONDS[1], AI.IDLE_SECONDS[2]),
		lastAttackAt = 0,
		lastSeenAt = nil,
		lastSeenPosition = nil,
		investigatePoint = nil,
		wanderGoal = nil,
		waypoints = nil,
		waypointIndex = 2,
		nextPathAt = 0,
	}
	zombies[model] = record
	activeCount += 1

	model:PivotTo(CFrame.new(spawnPosition + Vector3.new(0, 3.5, 0)))
	model.Parent = zombieFolder
	root:SetNetworkOwner(nil) -- el servidor controla la física del infectado

	humanoid.Died:Connect(function()
		kill(record)
	end)

	return model
end

-- Resta vida. source es el jugador que atacó. Devuelve true si el golpe lo mató.
function ZombieService:Damage(model: Instance, amount: number, source: Player?): boolean
	local record = zombies[model]
	if not record or record.dead or typeof(amount) ~= "number" or amount <= 0 then
		return false
	end
	record.lastAttacker = source
	local newHealth = record.humanoid.Health - amount
	if newHealth <= 0 then
		kill(record)
		return true
	end
	record.humanoid.Health = newHealth
	return false
end

-- Dado cualquier objeto (una parte golpeada, un accesorio...), devuelve el modelo
-- del infectado al que pertenece, o nil si no es de un infectado.
function ZombieService:FromInstance(instance: Instance?): Model?
	local current = instance
	while current and current ~= workspace do
		if zombies[current] then
			return current
		end
		current = current.Parent
	end
	return nil
end

-- Manda al infectado a investigar un punto (ruido, último lugar visto...).
-- Si ya persigue o ataca, lo ignora. Lo usará el oído del día 3.
function ZombieService:Investigate(model: Instance, position: Vector3): boolean
	local record = zombies[model]
	if not record or record.dead then
		return false
	end
	if record.state == "Chase" or record.state == "Attack" then
		return false
	end
	record.investigatePoint = position
	enterState(record, "Investigate", os.clock())
	return true
end

function ZombieService:GetState(model: Instance): string?
	local record = zombies[model]
	return record and record.state
end

function ZombieService:GetRecord(model: Instance)
	return zombies[model]
end

function ZombieService:IsDead(model: Instance): boolean
	local record = zombies[model]
	return record == nil or record.dead
end

-- Cantidad de infectados vivos.
function ZombieService:CountActive(): number
	return activeCount
end

-- Ciclo de vida -----------------------------------------------------------

function ZombieService:Init()
	zombieFolder = workspace:FindFirstChild("Zombies")
	if not zombieFolder then
		zombieFolder = Instance.new("Folder")
		zombieFolder.Name = "Zombies"
		zombieFolder.Parent = workspace
	end
end

function ZombieService:Start()
	-- Crear el modelo base ya, para que el primer Spawn no espere.
	task.spawn(getTemplate)

	-- Oído: un ruido atrae a los infectados que lo oyen (según el radio del ruido y la
	-- sensibilidad de su tipo). Los que ya persiguen o atacan lo ignoran.
	local NoiseService = require(script.Parent.NoiseService)
	NoiseService:Subscribe(function(position: Vector3, radius: number)
		for model, record in zombies do
			if not record.dead and Vision.heardNoise(record.root.Position, position, radius, record.config.hearingMultiplier) then
				ZombieService:Investigate(model, position)
			end
		end
	end)

	-- Un solo ciclo piensa por todos los infectados. Cada uno corre en su propio hilo
	-- porque calcular una ruta espera, y no debe frenar a los demás.
	task.spawn(function()
		while true do
			task.wait(AI.STEP_SECONDS)
			local now = os.clock()
			for _, record in zombies do
				if not record.dead and not record.busy then
					record.busy = true
					task.spawn(function()
						local ok, err = pcall(step, record, now)
						record.busy = false
						if not ok then
							warn(`[ZombieService] Error de IA: {err}`)
						end
					end)
				end
			end
		end
	end)

	-- Solo en Studio: poner el atributo DevSpawnZombies del Workspace a un número
	-- hace aparecer esa cantidad de infectados frente a la casa de prueba.
	-- DevSpawnType elige el tipo (por defecto Walker).
	if RunService:IsStudio() then
		workspace:GetAttributeChangedSignal("DevSpawnZombies"):Connect(function()
			local amount = workspace:GetAttribute("DevSpawnZombies")
			if typeof(amount) ~= "number" or amount < 1 then
				return
			end
			workspace:SetAttribute("DevSpawnZombies", nil)
			local typeId = workspace:GetAttribute("DevSpawnType")
			if not ZombieConfig[typeId] then
				typeId = "Walker"
			end
			for i = 1, math.min(amount, 50) do
				local column = (i - 1) % 5
				local row = math.floor((i - 1) / 5)
				ZombieService:Spawn(typeId, Vector3.new(30 + column * 4, 0, 30 + row * 4))
			end
		end)
	end
end

return ZombieService
