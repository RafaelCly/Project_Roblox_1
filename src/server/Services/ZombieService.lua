--!nonstrict
-- ZombieService
-- Aparición, vida y muerte de infectados. Dueño: Rafael.
-- Contrato con Axel (docs/plan-semana-2.md):
--   ZombieService:Damage(model, amount, source) -> true si lo mató
--   ZombieService:FromInstance(instance)        -> modelo del infectado o nil
-- Pendiente (días 2 y 3): máquina de estados, movimiento, visión y oído.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ZombieConfig = require(Shared.Config.Zombies)
local RunConfig = require(Shared.Config.Run)

local ZombieService = {}

local CORPSE_SECONDS = 3
local SKIN_COLOR = Color3.fromRGB(105, 135, 85)
local CLOTH_COLOR = Color3.fromRGB(70, 70, 75)

local zombies = {} -- [Model] = registro
local activeCount = 0
local zombieFolder = nil
local template = nil
local templateLoading = false

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

-- Suelo bajo una posición, para que no aparezcan dentro de una pared o en el aire.
local function groundPosition(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { zombieFolder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(position + Vector3.new(0, 50, 0), Vector3.new(0, -200, 0), params)
	local y = result and result.Position.Y or position.Y
	return Vector3.new(position.X, y, position.Z)
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

	local record = {
		model = model,
		humanoid = humanoid,
		root = root,
		config = config,
		typeId = typeId,
		state = "Idle",
		dead = false,
		lastAttacker = nil,
	}
	zombies[model] = record
	activeCount += 1

	model:PivotTo(CFrame.new(groundPosition(position) + Vector3.new(0, 3.5, 0)))
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
