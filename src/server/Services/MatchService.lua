--!nonstrict
-- MatchService
-- Máquina de estados y reloj de la partida (30 minutos). Dueño: Rafael.
-- Se llama MatchService para no chocar con el servicio nativo RunService de Roblox.
--
-- Flujo de una partida (docs/plan-semana-3.md):
--   Begin(players) -> Looting -> (oleadas y búnker: WaveService y BunkerService) -> Won o Lost
--   -> pausa de RESULT_PAUSE_SECONDS con el resultado -> limpieza -> Lobby
--
-- Pide el mapa a MapService:Generate(seed) y lo borra con MapService:Clear(). Mientras
-- MapService (de Axel) no tenga Generate, usa Dev/FakeMap, que devuelve un MapInfo igual.
-- Durante la partida no hay reaparición automática: un jugador muerto espera a que
-- termine. Si mueren todos, o se acaba el reloj, el resultado es Lost.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local RunConfig = require(Shared.Config.Run)
local Dev = require(Shared.Config.Dev)

local MatchService = {}

MatchService.States = {
	Lobby = "Lobby",
	Looting = "Looting",
	Wave = "Wave",
	BunkerDefense = "BunkerDefense",
	Won = "Won",
	Lost = "Lost",
}

local TICK_SECONDS = 0.25

local state = MatchService.States.Lobby
local stateListeners = {}
local endListeners = {}

local running = false -- hay una partida en curso (incluye la pausa del resultado)
local ended = false -- ya hay resultado; falta la pausa y la limpieza
local matchId = 0
local participants = {} -- lista de Player
local startedAt = 0
local timeScale = 1
local mapInfo = nil
local activeMap = nil -- { Generate = function, Clear = function } con la misma firma que MapService

-- Mapa ----------------------------------------------------------------------

-- Devuelve un objeto con :Generate(seed) y :Clear(). Usa el MapService real si ya tiene
-- Generate; si no, el mapa falso.
local function resolveMap()
	local ok, Map = pcall(require, script.Parent.MapService)
	if ok and type(Map) == "table" and type(Map.Generate) == "function" then
		return Map
	end
	local FakeMap = require(script.Parent.Parent.Dev.FakeMap)
	return {
		Generate = function(_, seed)
			return FakeMap.generate(seed)
		end,
		Clear = function()
			FakeMap.clear()
		end,
	}
end

-- Utilidades ----------------------------------------------------------------

local function characterOf(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return character, humanoid, root
end

local function countAlive(): number
	local alive = 0
	for _, player in participants do
		if player.Parent == Players then
			local _, humanoid = characterOf(player)
			if humanoid and humanoid.Health > 0 then
				alive += 1
			end
		end
	end
	return alive
end

-- Quita todo lo que lleva el jugador: se empieza "sin nada".
local function emptyInventory(player: Player)
	local Inventory = require(script.Parent.InventoryService)
	local Combat = require(script.Parent.CombatService)
	pcall(function()
		Combat:Unequip(player)
	end)
	local inventory = Inventory:Get(player)
	if not inventory then
		return
	end
	local stacks = {}
	for i = 1, inventory.slotCount do
		local stack = inventory.slots[i]
		if stack then
			table.insert(stacks, { id = stack.id, count = stack.count })
		end
	end
	for _, stack in stacks do
		Inventory:RemoveItem(player, stack.id, stack.count)
	end
end

-- Crea un personaje nuevo y lo coloca en un punto de aparición.
local function spawnPlayer(player: Player, position: Vector3)
	-- Justo después de LoadCharacter, player.Character puede seguir siendo el personaje
	-- viejo (a punto de destruirse): hay que esperar a uno distinto del anterior.
	local previous = player.Character
	player:LoadCharacter()
	local character = player.Character
	local deadline = os.clock() + 10
	while (not character or character == previous or not character:FindFirstChild("HumanoidRootPart")) and os.clock() < deadline do
		task.wait(0.1)
		character = player.Character
	end
	if character and character:FindFirstChild("HumanoidRootPart") then
		character:PivotTo(CFrame.new(position + Vector3.new(0, 3, 0)))
	end
end

-- Estado ----------------------------------------------------------------------

-- Segundos de partida transcurridos, ya con la velocidad del reloj (MATCH_TIME_SCALE).
function MatchService:GetElapsed(): number
	if not running then
		return 0
	end
	return (os.clock() - startedAt) * timeScale
end

-- Momento (hora del servidor) en que se acaba el reloj, al ritmo actual. 0 si no hay partida.
function MatchService:GetEndsAt(): number
	if not running then
		return 0
	end
	return workspace:GetServerTimeNow() + (RunConfig.RUN_DURATION_SECONDS - MatchService:GetElapsed()) / timeScale
end

function MatchService:GetState()
	return state
end

function MatchService:IsRunning(): boolean
	return running
end

-- MapInfo de la partida en curso, o nil.
function MatchService:GetMapInfo()
	return mapInfo
end

-- Los jugadores de la partida en curso (copia).
function MatchService:GetParticipants()
	return table.clone(participants)
end

-- Cambia de estado, avisa a los suscritos y a todos los clientes.
function MatchService:SetState(newState)
	assert(MatchService.States[newState], `Estado inválido: {tostring(newState)}`)
	if newState == state then
		return
	end
	local old = state
	state = newState
	for _, callback in stateListeners do
		task.spawn(callback, newState, old)
	end
	Remotes.get("RunStateChanged"):FireAllClients(newState, MatchService:GetEndsAt())
end

function MatchService:OnStateChanged(callback)
	table.insert(stateListeners, callback)
end

-- callback(resultado, datos): resultado es "Won" o "Lost"; datos = { elapsed, participants, survivors }.
function MatchService:OnEnded(callback)
	table.insert(endListeners, callback)
end

-- Limpieza ----------------------------------------------------------------------

-- Cada paso va aparte con pcall: aunque uno falle, el resto se hace y el servidor vuelve a
-- poder empezar otra partida (sobre todo, la reaparición automática se restaura siempre).
local function cleanup()
	local function step(name: string, fn)
		local ok, err = pcall(fn)
		if not ok then
			warn(`[MatchService] Falló la limpieza ({name}): {err}`)
		end
	end

	step("mapa", function()
		if activeMap then
			activeMap:Clear()
		end
	end)
	step("infectados", function()
		require(script.Parent.ZombieService):Clear()
	end)
	step("objetos del suelo", function()
		local pickups = workspace:FindFirstChild("Pickups")
		if pickups then
			pickups:ClearAllChildren()
		end
	end)

	Players.CharacterAutoLoads = true
	for _, player in participants do
		if player.Parent == Players then
			step("personaje de " .. player.Name, function()
				player:LoadCharacter()
			end)
		end
	end

	participants = {}
	mapInfo = nil
	activeMap = nil
	running = false
	ended = false
	MatchService:SetState("Lobby")
end

-- Termina la partida con "Won" o "Lost". Devuelve false si no hay partida o ya terminó.
function MatchService:End(result): boolean
	if result ~= "Won" and result ~= "Lost" then
		return false
	end
	if not running or ended then
		return false
	end
	ended = true

	local data = {
		elapsed = MatchService:GetElapsed(),
		participants = #participants,
		survivors = countAlive(),
	}
	MatchService:SetState(result)
	for _, callback in endListeners do
		task.spawn(callback, result, data)
	end

	local thisMatch = matchId
	task.delay(RunConfig.RESULT_PAUSE_SECONDS, function()
		if matchId == thisMatch then
			cleanup()
		end
	end)
	return true
end

-- Empieza una partida con estos jugadores. Devuelve false si no se pudo (ya hay una en
-- curso, la lista está vacía, trae algo que no es un jugador, o falló el mapa).
function MatchService:Begin(players): boolean
	if running or typeof(players) ~= "table" then
		return false
	end
	local list = {}
	for _, player in players do
		if typeof(player) == "Instance" and player:IsA("Player") and player.Parent == Players then
			table.insert(list, player)
		else
			return false
		end
	end
	if #list == 0 or #list > RunConfig.MAX_PLAYERS then
		return false
	end

	running = true
	ended = false
	matchId += 1
	local thisMatch = matchId
	participants = list
	timeScale = math.max(1, Dev.MATCH_TIME_SCALE or 1)

	Players.CharacterAutoLoads = false
	local ok, err = pcall(function()
		activeMap = resolveMap()
		mapInfo = activeMap:Generate(os.time() + thisMatch)
		assert(mapInfo and mapInfo.playerSpawns and #mapInfo.playerSpawns >= 1, "el mapa no trae puntos de aparición")

		for index, player in list do
			emptyInventory(player)
			local spawns = mapInfo.playerSpawns
			spawnPlayer(player, spawns[(index - 1) % #spawns + 1])
		end
	end)
	if not ok then
		warn(`[MatchService] No se pudo empezar la partida: {err}`)
		cleanup()
		return false
	end

	startedAt = os.clock()
	MatchService:SetState("Looting")

	task.spawn(function()
		while running and matchId == thisMatch and not ended do
			task.wait(TICK_SECONDS)
			if not running or matchId ~= thisMatch or ended then
				break
			end
			if countAlive() == 0 then
				MatchService:End("Lost")
				break
			end
			if MatchService:GetElapsed() >= RunConfig.RUN_DURATION_SECONDS then
				MatchService:End("Lost")
				break
			end
		end
	end)
	return true
end

-- Ciclo de vida -----------------------------------------------------------

function MatchService:Init() end

function MatchService:Start()
	-- Solo en Studio, desde la barra de comandos de la pestaña Servidor:
	--   workspace:SetAttribute("DevStartMatch", true)   empieza una partida con todos
	--   workspace:SetAttribute("DevEndMatch", "Won")    la termina con "Won" o "Lost"
	if not RunService:IsStudio() then
		return
	end
	workspace:GetAttributeChangedSignal("DevStartMatch"):Connect(function()
		if workspace:GetAttribute("DevStartMatch") then
			workspace:SetAttribute("DevStartMatch", nil)
			task.spawn(function()
				local started = MatchService:Begin(Players:GetPlayers())
				print(`[MatchService] DevStartMatch: {started and "partida iniciada" or "no se pudo empezar"}`)
			end)
		end
	end)
	workspace:GetAttributeChangedSignal("DevEndMatch"):Connect(function()
		local result = workspace:GetAttribute("DevEndMatch")
		if result then
			workspace:SetAttribute("DevEndMatch", nil)
			print(`[MatchService] DevEndMatch {tostring(result)}: {MatchService:End(result) and "ok" or "ignorado"}`)
		end
	end)
end

return MatchService
