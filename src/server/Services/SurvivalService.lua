--!nonstrict
-- SurvivalService
-- Vida (Humanoid) y hambre. El hambre baja sola; con hambre en 0 se pierde vida.
-- Pendiente (semana 2): resistencia, estado de caído y levantar (1 vez por jugador).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Config = require(Shared.Config.Survival)

local SurvivalService = {}

local states = {} -- [Player] = { hunger = number }

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
	states[player] = { hunger = Config.START_HUNGER }
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
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
	return true
end

function SurvivalService:IsAlive(player: Player): boolean
	local humanoid = getHumanoid(player)
	return humanoid ~= nil and humanoid.Health > 0
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
				if humanoid and humanoid.Health > 0 then
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
