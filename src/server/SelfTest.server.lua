--!nonstrict
-- Pruebas automáticas del servidor. Solo corren dentro de Roblox Studio.
-- Resultado en la ventana Output: busca "[Test]". Cada línea es PASS o FAIL.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not RunService:IsStudio() then
	return
end

task.wait(2) -- deja que Main termine de iniciar los servicios

local passed, failed = 0, 0

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		print(`[Test] PASS {name}`)
	else
		failed += 1
		warn(`[Test] FAIL {name}{detail and (" - " .. detail) or ""}`)
	end
end

local function section(name: string)
	print(`[Test] ---- {name}`)
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local servicesFolder = script.Parent:WaitForChild("Services")

-- Remotes -------------------------------------------------------------------
section("Remotes")
local Remotes = require(Shared:WaitForChild("Remotes"))
local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
check("carpeta Remotes existe", remotesFolder ~= nil)
if remotesFolder then
	for _, name in Remotes.Names do
		local remote = remotesFolder:FindFirstChild(name)
		check(`remote {name}`, remote ~= nil and remote:IsA("RemoteEvent"))
	end
end

-- Config --------------------------------------------------------------------
section("Config")
local Weapons = require(Shared.Config.Weapons)
for id, weapon in Weapons do
	check(`arma {id}: valores válidos`, weapon.damage > 0 and weapon.range > 0 and weapon.cooldown > 0 and weapon.noiseRadius >= 0)
	if weapon.kind == "Firearm" then
		check(`arma {id}: tiene cargador y recarga`, weapon.magazineSize ~= nil and weapon.reloadTime ~= nil)
	end
end
check("el cuchillo es más silencioso que el bate", Weapons.Knife.noiseRadius < Weapons.Bat.noiseRadius)
check("el bate es más silencioso que la pistola", Weapons.Bat.noiseRadius < Weapons.Pistol.noiseRadius)

local Zombies = require(Shared.Config.Zombies)
for id, zombie in Zombies do
	check(`infectado {id}: valores válidos`, zombie.health > 0 and zombie.chaseSpeed >= zombie.walkSpeed and zombie.sightAngle > 0 and zombie.budgetCost > 0)
end

local RunConfig = require(Shared.Config.Run)
check("grupo: mínimo <= máximo", RunConfig.MIN_PLAYERS_TO_START <= RunConfig.MAX_PLAYERS)
check("grupo: máximo es 4", RunConfig.MAX_PLAYERS == 4)
check("grupo: se puede empezar con 2", RunConfig.MIN_PLAYERS_TO_START == 2)
check("revivir: 1 vez por jugador", RunConfig.REVIVES_PER_PLAYER == 1)
check("partida: máximo 30 minutos", RunConfig.RUN_DURATION_SECONDS <= 30 * 60)
local wavesOk = #RunConfig.Waves == 3
local previousStart = -1
local previousBudget = -1
for _, wave in RunConfig.Waves do
	if wave.startsAt <= previousStart or wave.budget <= previousBudget or wave.startsAt >= RunConfig.RUN_DURATION_SECONDS then
		wavesOk = false
	end
	previousStart, previousBudget = wave.startsAt, wave.budget
end
check("3 oleadas en orden creciente y dentro de la partida", wavesOk)

-- Servicios -----------------------------------------------------------------
section("Servicios")
local loaded = {}
for _, moduleScript in servicesFolder:GetChildren() do
	if moduleScript:IsA("ModuleScript") then
		local ok, result = pcall(require, moduleScript)
		check(`servicio {moduleScript.Name} carga`, ok and type(result) == "table", not ok and tostring(result) or nil)
		if ok then
			loaded[moduleScript.Name] = result
		end
	end
end
check("hay 14 servicios", next(loaded) ~= nil and #servicesFolder:GetChildren() == 14, `{#servicesFolder:GetChildren()}`)

-- MatchService --------------------------------------------------------------
section("MatchService")
local Match = loaded.MatchService
if Match then
	check("estado inicial es Lobby", Match:GetState() == "Lobby")
	local seen = {}
	Match:OnStateChanged(function(new, old)
		table.insert(seen, `{old}->{new}`)
	end)
	Match:SetState("Looting")
	Match:SetState("Looting") -- repetido: no debe avisar dos veces
	Match:SetState("Wave")
	task.wait()
	check("cambia de estado", Match:GetState() == "Wave")
	check("avisa cada cambio una sola vez", #seen == 2 and seen[1] == "Lobby->Looting" and seen[2] == "Looting->Wave", table.concat(seen, ","))
	check("rechaza un estado inválido", not pcall(Match.SetState, Match, "Inventado"))
	Match:SetState("Lobby") -- dejar como estaba
end

-- NoiseService --------------------------------------------------------------
section("NoiseService")
local Noise = loaded.NoiseService
if Noise then
	local got
	Noise:Subscribe(function(position, radius, source)
		got = { position = position, radius = radius, source = source }
	end)
	Noise:Emit(Vector3.new(1, 2, 3), Weapons.Pistol.noiseRadius, nil)
	task.wait()
	check("entrega el ruido al suscriptor", got ~= nil and got.position == Vector3.new(1, 2, 3) and got.radius == 120)
end

-- DataService ---------------------------------------------------------------
section("DataService")
local Data = loaded.DataService
if Data then
	local player = Players:GetPlayers()[1]
	if not player then
		player = Players.PlayerAdded:Wait()
	end
	local profile = Data:WaitForProfile(player)
	check("el jugador recibe un perfil", profile ~= nil)
	if profile then
		check("perfil: estadísticas por defecto", profile.stats.runsPlayed == 0 and profile.stats.runsWon == 0 and profile.stats.zombiesKilled == 0)
		check("perfil: cosméticos por defecto", type(profile.cosmetics.owned) == "table" and type(profile.cosmetics.equipped) == "table")
		check("perfil: versión 1", profile.version == 1)
		Data:Update(player, function(p)
			p.stats.zombiesKilled += 5
		end)
		check("Update modifica el perfil", Data:Get(player).stats.zombiesKilled == 5)
		Data:Update(player, function(p)
			p.stats.zombiesKilled = 0
		end)
		print(`[Test] INFO perfil guardable: {profile._unsaveable ~= true} (false es normal en Studio sin publicar)`)
	end
end

print(`[Test] RESULTADO: {passed} PASS, {failed} FAIL`)
