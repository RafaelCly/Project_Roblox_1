--!nonstrict
-- SurvivalService
-- Vida (Humanoid) y hambre. El hambre baja sola; con hambre en 0 se pierde vida.
-- Caído: la primera vez que el daño mataría al jugador queda caído (ver Damage y Revive).
-- Pendiente: resistencia para correr (semana 3 o después).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Config = require(Shared.Config.Survival)
local RunConfig = require(Shared.Config.Run)

local SurvivalService = {}

-- [Player] = { hunger = number, downs = veces que ha caído, downed = nil | { prompt, baseWalkSpeed } }
-- Se reinicia con cada personaje nuevo: una muerte termina la partida de ese jugador.
local states = {}

local DOWNED_ATTRIBUTE = "Downed"
local DOWNED_ENDS_ATTRIBUTE = "DownedEndsAt"

-- Función pura: devuelve el hambre nueva y si el jugador se está muriendo de hambre.
function SurvivalService.stepHunger(hunger: number, dt: number)
	local newHunger = math.max(0, hunger - Config.HUNGER_DECAY_PER_SECOND * dt)
	return newHunger, newHunger <= 0
end

local function getHumanoid(player: Player)
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function push(player: Player)
	local state = states[player]
	local humanoid = getHumanoid(player)
	if not state or not humanoid then
		return
	end
	Remotes.get("SurvivalChanged"):FireClient(player, humanoid.Health, humanoid.MaxHealth, state.hunger, Config.MAX_HUNGER)
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	states[player] = { hunger = Config.START_HUNGER, downs = 0 }
	player:SetAttribute(DOWNED_ATTRIBUTE, nil)
	player:SetAttribute(DOWNED_ENDS_ATTRIBUTE, nil)
	humanoid.Died:Connect(function()
		local state = states[player]
		if state and state.downed then
			SurvivalService:_clearDowned(player)
		end
	end)
	humanoid.MaxHealth = Config.MAX_HEALTH
	humanoid.Health = Config.MAX_HEALTH
	humanoid.HealthChanged:Connect(function()
		push(player)
	end)
	push(player)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

function SurvivalService:GetHunger(player: Player): number?
	local state = states[player]
	return state and state.hunger
end

function SurvivalService:SetHunger(player: Player, value: number)
	local state = states[player]
	if state then
		state.hunger = math.clamp(value, 0, Config.MAX_HUNGER)
		push(player)
	end
end

-- Sube el hambre. Devuelve false si ya estaba llena (el objeto no se consume).
function SurvivalService:Feed(player: Player, amount: number): boolean
	local state = states[player]
	if not state or state.hunger >= Config.MAX_HUNGER then
		return false
	end
	state.hunger = math.min(Config.MAX_HUNGER, state.hunger + amount)
	push(player)
	return true
end

-- Sube la vida. Devuelve false si estaba completa o el jugador está muerto.
function SurvivalService:Heal(player: Player, amount: number): boolean
	local humanoid = getHumanoid(player)
	if not humanoid or humanoid.Health <= 0 or humanoid.Health >= humanoid.MaxHealth then
		return false
	end
	-- Un caído solo se recupera si lo levantan un compañero.
	if SurvivalService:IsDowned(player) then
		return false
	end
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
	return true
end

function SurvivalService:IsAlive(player: Player): boolean
	local humanoid = getHumanoid(player)
	return humanoid ~= nil and humanoid.Health > 0
end

-- Caído y levantar --------------------------------------------------------

-- ¿Está el jugador caído esperando ayuda?
function SurvivalService:IsDowned(player): boolean
	local state = states[player]
	return state ~= nil and state.downed ~= nil
end

-- Quita el estado de caído sin tocar la vida (la usan levantar y morir).
function SurvivalService:_clearDowned(player)
	local state = states[player]
	if not state or not state.downed then
		return
	end
	local prompt = state.downed.prompt
	if prompt then
		prompt:Destroy()
	end
	state.downed = nil
	player:SetAttribute(DOWNED_ATTRIBUTE, nil)
	player:SetAttribute(DOWNED_ENDS_ATTRIBUTE, nil)
end

local function kill(player)
	SurvivalService:_clearDowned(player)
	local humanoid = getHumanoid(player)
	if humanoid then
		humanoid.Health = 0
	end
end

-- Un compañero mantiene pulsado "Levantar" junto al caído.
local function makeRevivePrompt(player, root: BasePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RevivePrompt"
	prompt.ActionText = "Levantar"
	prompt.ObjectText = player.DisplayName
	prompt.HoldDuration = Config.REVIVE_HOLD_SECONDS
	prompt.MaxActivationDistance = Config.REVIVE_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	prompt.Triggered:Connect(function(helper)
		SurvivalService:Revive(helper, player)
	end)
	return prompt
end

local function goDown(player, humanoid: Humanoid)
	local state = states[player]
	state.downs += 1
	state.downed = { baseWalkSpeed = humanoid.WalkSpeed }
	humanoid.Health = 1
	humanoid.WalkSpeed = Config.DOWNED_WALK_SPEED

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root then
		state.downed.prompt = makeRevivePrompt(player, root)
	end
	player:SetAttribute(DOWNED_ATTRIBUTE, true)
	player:SetAttribute(DOWNED_ENDS_ATTRIBUTE, workspace:GetServerTimeNow() + RunConfig.DOWNED_SECONDS)

	-- Con el arma en la mano no se puede hacer nada: se guarda.
	require(script.Parent.CombatService):Unequip(player)

	local downed = state.downed
	task.delay(RunConfig.DOWNED_SECONDS, function()
		-- Si lo levantaron o murió antes, el estado ya no es el mismo.
		if states[player] and states[player].downed == downed then
			kill(player)
		end
	end)
end

-- Resta vida a un jugador. Aquí vive la regla de "caído": la primera vez que el daño lo
-- mataría, queda caído con 1 de vida; la segunda vez, o si ya estaba caído, muere.
-- Devuelve "hurt", "downed", "dead" o "ignored". `source` es quien hizo el daño.
function SurvivalService:Damage(player, amount: number, source: any?): string
	local state = states[player]
	local humanoid = getHumanoid(player)
	if not state or not humanoid or humanoid.Health <= 0 then
		return "ignored"
	end
	if typeof(amount) ~= "number" or not (amount > 0) then
		return "ignored"
	end

	if state.downed then
		kill(player)
		return "dead"
	end
	if humanoid.Health - amount > 0 then
		humanoid:TakeDamage(amount)
		return "hurt"
	end
	if state.downs < RunConfig.REVIVES_PER_PLAYER then
		goDown(player, humanoid)
		return "downed"
	end
	humanoid.Health = 0
	return "dead"
end

-- Un compañero levanta a `target`. Devuelve false si no se puede.
function SurvivalService:Revive(helper, target): boolean
	local state = states[target]
	if helper == target or not state or not state.downed then
		return false
	end

	local helperHumanoid = getHumanoid(helper)
	if not helperHumanoid or helperHumanoid.Health <= 0 or SurvivalService:IsDowned(helper) then
		return false
	end
	local helperRoot = helper.Character and helper.Character:FindFirstChild("HumanoidRootPart")
	local targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	local humanoid = getHumanoid(target)
	if not helperRoot or not targetRoot or not humanoid then
		return false
	end
	local maxDistance = Config.REVIVE_DISTANCE + Config.REVIVE_DISTANCE_TOLERANCE
	if (helperRoot.Position - targetRoot.Position).Magnitude > maxDistance then
		return false
	end

	humanoid.WalkSpeed = state.downed.baseWalkSpeed
	SurvivalService:_clearDowned(target)
	humanoid.Health = Config.REVIVE_HEALTH
	Remotes.get("Notify"):FireClient(target, `{helper.DisplayName} te levantó`)
	return true
end

function SurvivalService:Init() end

function SurvivalService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			for player, state in states do
				local humanoid = getHumanoid(player)
				-- Un caído no muere de hambre: su tiempo lo marca el estado de caído.
				if humanoid and humanoid.Health > 0 and not state.downed then
					local newHunger, starving = SurvivalService.stepHunger(state.hunger, 1)
					state.hunger = newHunger
					if starving then
						humanoid:TakeDamage(Config.STARVE_DAMAGE_PER_SECOND)
					end
					push(player)
				end
			end
		end
	end)
end

return SurvivalService
