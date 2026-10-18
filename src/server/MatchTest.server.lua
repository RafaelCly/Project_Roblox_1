--!nonstrict
-- Pruebas de la partida (MatchService) con un jugador. Solo corren dentro de Roblox Studio.
-- Resultado en la ventana Output: busca "[TestMatch]".
--
-- Cuándo corren:
--   Dev.ONLY_TEST = nil      al terminar SelfTest (la suite completa), si hay 1 jugador.
--   Dev.ONLY_TEST = "match"  solas, sin esperar a SelfTest: tardan menos de un minuto.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Dev = require(Shared.Config.Dev)
if not Dev.RUN_SELF_TESTS then
	return
end
if Dev.ONLY_TEST and Dev.ONLY_TEST ~= "match" then
	return
end

if Dev.ONLY_TEST then
	task.wait(8) -- que Main inicie los servicios
else
	local deadline = os.clock() + 900
	while not workspace:GetAttribute("SelfTestDone") and os.clock() < deadline do
		task.wait(1)
	end
	if not workspace:GetAttribute("SelfTestDone") then
		return
	end
end

-- Con 2 jugadores la prueba de MultiplayerTest ya usa el servidor; estas son de 1 jugador.
local joinDeadline = os.clock() + 20
while #Players:GetPlayers() < 1 and os.clock() < joinDeadline do
	task.wait(0.5)
end
if #Players:GetPlayers() ~= 1 then
	print("[TestMatch] INFO se necesita exactamente 1 jugador; se omiten las pruebas de la partida")
	return
end

local services = script.Parent:WaitForChild("Services")
local Match = require(services.MatchService)
local Inventory = require(services.InventoryService)
local ZombieSvc = require(services.ZombieService)
local FakeMap = require(script.Parent.Dev.FakeMap)
local RunConfig = require(Shared.Config.Run)

local passed, failed = 0, 0

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		print(`[TestMatch] PASS {name}`)
	else
		failed += 1
		warn(`[TestMatch] FAIL {name}{detail and (" - " .. detail) or ""}`)
	end
end

local function section(name: string)
	print(`[TestMatch] ---- {name}`)
end

local function waitUntil(predicate, timeout: number): boolean
	local deadline = os.clock() + timeout
	while os.clock() < deadline do
		if predicate() then
			return true
		end
		task.wait(0.1)
	end
	return predicate()
end

local function waitAlive(player: Player, timeout: number)
	local startedAt = os.clock()
	while os.clock() - startedAt < timeout do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 then
			for _, child in character:GetChildren() do
				if child:IsA("ForceField") then
					child:Destroy()
				end
			end
			return character, humanoid, root
		end
		task.wait(0.2)
	end
	return nil
end

local player = Players:GetPlayers()[1]
local originalPause = RunConfig.RESULT_PAUSE_SECONDS
local originalScale = Dev.MATCH_TIME_SCALE
RunConfig.RESULT_PAUSE_SECONDS = 1 -- la pausa del resultado, acortada para las pruebas

if not waitAlive(player, 20) then
	warn("[TestMatch] FAIL el jugador de prueba no está vivo para empezar")
	print("[TestMatch] RESULTADO PARTIDA: 0 PASS, 1 FAIL")
	return
end

local endedLog = {}
Match:OnEnded(function(result, data)
	table.insert(endedLog, { result = result, data = data })
end)

-- Mapa falso ---------------------------------------------------------------------------
section("Mapa falso (FakeMap)")
local mapA = FakeMap.generate(7)
check("trae al menos 4 puntos de aparición, 1 de infectados y 6 de piezas", #mapA.playerSpawns >= 4 and #mapA.zombieSpawns >= 1 and #mapA.partPoints >= 6)
check("trae la puerta y el interior del búnker", mapA.bunker.door ~= nil and mapA.bunker.door:IsA("BasePart") and mapA.bunker.interior ~= nil and mapA.bunker.doorPosition ~= nil)
local firstPart = mapA.partPoints[1]
local mapB = FakeMap.generate(7)
check("la misma semilla da el mismo mapa", mapB.partPoints[1] == firstPart and mapB.zombieSpawns[3] == mapA.zombieSpawns[3])
local mapC = FakeMap.generate(8)
check("otra semilla da otro mapa", mapC.partPoints[1] ~= firstPart)
FakeMap.clear()
check("Clear borra el mapa", workspace:FindFirstChild("FakeMatchMap") == nil)

-- Limpieza de infectados ----------------------------------------------------------------------
section("ZombieService:Clear")
for i = 1, 3 do
	ZombieSvc:Spawn("Walker", Vector3.new(i * 4, 0, 80))
end
check("hay 3 infectados antes de limpiar", ZombieSvc:CountActive() == 3)
ZombieSvc:Clear()
check("Clear deja 0 infectados y la carpeta vacía", ZombieSvc:CountActive() == 0 and #workspace.Zombies:GetChildren() == 0)

-- Partidas inválidas --------------------------------------------------------------------------
section("Empezar una partida")
Inventory:AddItem(player, "Bandage", 2)
check("antes de empezar el estado es Lobby", Match:GetState() == "Lobby" and Match:IsRunning() == false)
check("una lista vacía se rechaza", Match:Begin({}) == false)
check("algo que no es una lista se rechaza", Match:Begin(nil) == false and Match:Begin("hola") == false)
check("algo que no es un jugador se rechaza", Match:Begin({ workspace }) == false)
check("lo rechazado no deja nada a medias", Match:IsRunning() == false and Players.CharacterAutoLoads == true)

-- Partida 1: se acaba el reloj -----------------------------------------------------------------
section("Partida 1: se acaba el tiempo")
Dev.MATCH_TIME_SCALE = 900 -- 30 minutos pasan en 2 segundos
local stateChanges = {}
Match:OnStateChanged(function(new, old)
	table.insert(stateChanges, `{old}->{new}`)
end)
check("Begin arranca la partida", Match:Begin({ player }) == true)
check("el estado pasa a Looting", Match:GetState() == "Looting" and Match:IsRunning() == true)
local info = Match:GetMapInfo()
check("hay un MapInfo con los datos que exige el contrato", info ~= nil and #info.playerSpawns >= 1 and #info.zombieSpawns >= 1 and #info.partPoints >= 3 and info.bunker ~= nil and info.bunker.door ~= nil and info.bunker.interior ~= nil)
check("no hay reaparición automática durante la partida", Players.CharacterAutoLoads == false)
check("no se puede empezar otra partida a la vez", Match:Begin({ player }) == false)

local _, _, matchRoot = waitAlive(player, 10)
check("el jugador reaparece vivo", matchRoot ~= nil)
if matchRoot and info then
	local nearest = math.huge
	for _, spawnPoint in info.playerSpawns do
		nearest = math.min(nearest, (matchRoot.Position - spawnPoint).Magnitude)
	end
	check("aparece cerca de un punto de aparición", nearest < 15, tostring(nearest))
end
check("empieza sin nada en el inventario", Inventory:Count(player, "Bandage") == 0)
check("el reloj avanza", Match:GetElapsed() > 0)
check("hay una hora de fin en el futuro cercano", Match:GetEndsAt() > workspace:GetServerTimeNow() - 1)

ZombieSvc:Spawn("Walker", (matchRoot and matchRoot.Position or Vector3.zero) + Vector3.new(0, 0, 70))
check("hay un infectado vivo durante la partida", ZombieSvc:CountActive() == 1)

check("al acabarse el tiempo la partida termina en Lost", waitUntil(function()
	return Match:GetState() == "Lost"
end, 8))
check("OnEnded avisó una sola vez, con Lost y datos", #endedLog == 1 and endedLog[1].result == "Lost" and endedLog[1].data.participants == 1 and endedLog[1].data.elapsed >= RunConfig.RUN_DURATION_SECONDS)
check("terminar otra vez no hace nada", Match:End("Won") == false and #endedLog == 1)

check("tras la pausa vuelve a Lobby", waitUntil(function()
	return Match:GetState() == "Lobby" and Match:IsRunning() == false
end, 5))
check("se restaura la reaparición automática", Players.CharacterAutoLoads == true)
check("no quedan infectados", ZombieSvc:CountActive() == 0 and #workspace.Zombies:GetChildren() == 0)
check("el mapa se borró", Match:GetMapInfo() == nil and workspace:FindFirstChild("FakeMatchMap") == nil)
check("el jugador vuelve a tener un personaje vivo", waitAlive(player, 10) ~= nil)
check("los estados fueron Lobby, Looting, Lost y de vuelta a Lobby", table.concat(stateChanges, ",") == "Lobby->Looting,Looting->Lost,Lost->Lobby", table.concat(stateChanges, ","))

-- Partida 2: mueren todos --------------------------------------------------------------------------------
section("Partida 2: mueren todos")
Dev.MATCH_TIME_SCALE = 1
check("se puede empezar otra partida sin reiniciar el servidor", Match:Begin({ player }) == true)
local victimCharacter, victim = waitAlive(player, 10)
check("el jugador está vivo al empezar", victim ~= nil)
if victim then
	-- SurvivalService termina de preparar el personaje un instante después de que aparece y
	-- le repone la vida: matarlo en el primer fotograma sería deshacer ese ajuste.
	task.wait(1.5)
	victim.Health = 0
end
local diedAndLost = waitUntil(function()
	return Match:GetState() == "Lost"
end, 4)
check("si mueren todos el resultado es Lost", diedAndLost and #endedLog == 2 and endedLog[2].result == "Lost", `estado={Match:GetState()} avisos={#endedLog}`)
if not diedAndLost then
	Match:End("Lost") -- que un fallo aquí no arrastre a las partidas siguientes
end
check("el jugador muerto no reaparece durante la pausa", Players.CharacterAutoLoads == false)
check("vuelve a Lobby", waitUntil(function()
	return Match:GetState() == "Lobby"
end, 5))
check("la reaparición vuelve a ser automática", Players.CharacterAutoLoads == true)
waitAlive(player, 10)

-- Partida 3: victoria forzada --------------------------------------------------------------------------------
section("Partida 3: victoria")
check("otra partida más", Match:Begin({ player }) == true)
waitAlive(player, 10)
check("un resultado inventado se rechaza", Match:End("Inventado") == false and Match:End(nil) == false and Match:IsRunning() == true)
check("End('Won') termina la partida", Match:End("Won") == true and Match:GetState() == "Won")
check("OnEnded avisó Won con 1 superviviente", #endedLog == 3 and endedLog[3].result == "Won" and endedLog[3].data.survivors == 1)
check("no se puede terminar dos veces", Match:End("Lost") == false)
check("no se puede empezar otra durante la pausa del resultado", Match:Begin({ player }) == false)
check("vuelve a Lobby", waitUntil(function()
	return Match:GetState() == "Lobby"
end, 5))

-- Fuera de partida ----------------------------------------------------------------------------------------------------
section("Fuera de partida")
check("End sin partida en curso se ignora", Match:End("Won") == false)
check("el reloj fuera de partida marca 0", Match:GetElapsed() == 0 and Match:GetEndsAt() == 0)

-- Restaurar y terminar
Dev.MATCH_TIME_SCALE = originalScale
RunConfig.RESULT_PAUSE_SECONDS = originalPause
Players.CharacterAutoLoads = true
print(`[TestMatch] RESULTADO PARTIDA: {passed} PASS, {failed} FAIL`)
