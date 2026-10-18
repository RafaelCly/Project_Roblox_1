--!nonstrict
-- Pruebas automáticas del mapa modular (semana 3). Solo corren dentro de Roblox Studio.
-- Esperan a que termine SelfTest (atributo SelfTestDone del Workspace) para no mezclarse con él.
-- Resultado en Output: busca "[TestMapa]".

local CollectionService = game:GetService("CollectionService")
local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local deadline = os.clock() + 900
while not workspace:GetAttribute("SelfTestDone") and os.clock() < deadline do
	task.wait(1)
end
if not workspace:GetAttribute("SelfTestDone") then
	return
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared.Config.Map)
local MapGrid = require(Shared.Util.MapGrid)
local MapService = require(script.Parent.Services.MapService)

local passed, failed = 0, 0

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		print(`[TestMapa] PASS {name}`)
	else
		failed += 1
		warn(`[TestMapa] FAIL {name}{detail and (" - " .. detail) or ""}`)
	end
end

local function section(name: string)
	print(`[TestMapa] ---- {name}`)
end

local function vectorsEqual(a: { Vector3 }, b: { Vector3 }): boolean
	if #a ~= #b then
		return false
	end
	for i, v in a do
		if (v - b[i]).Magnitude > 0.001 then
			return false
		end
	end
	return true
end

-- Instancias de Workspace que no estaban en `before` y no son de otros sistemas (personajes,
-- recogibles, infectados, cámara): lo que el mapa dejó sin borrar.
local function snapshot(): { [Instance]: boolean }
	local set = {}
	for _, instance in workspace:GetDescendants() do
		set[instance] = true
	end
	return set
end

local function leftovers(before: { [Instance]: boolean }): number
	local ignored = { workspace.CurrentCamera, workspace:FindFirstChild("Pickups"), workspace:FindFirstChild("Zombies") }
	for _, player in Players:GetPlayers() do
		table.insert(ignored, player.Character)
	end
	local count = 0
	for _, instance in workspace:GetDescendants() do
		if not before[instance] then
			local skip = false
			for _, owner in ignored do
				if owner and (instance == owner or instance:IsDescendantOf(owner)) then
					skip = true
					break
				end
			end
			if not skip then
				count += 1
			end
		end
	end
	return count
end

-- Diseño de la cuadrícula (lógica pura) ---------------------------------------------------
section("Diseño de la cuadrícula")
local layoutA, layoutB = MapGrid.generate(12345, MapConfig), MapGrid.generate(12345, MapConfig)
check("la misma semilla da el mismo diseño", table.concat(layoutA.cells, ",") == table.concat(layoutB.cells, ","))
local different = false
for seed = 1, 30 do
	if table.concat(MapGrid.generate(seed, MapConfig).cells, ",") ~= table.concat(layoutA.cells, ",") then
		different = true
		break
	end
end
check("semillas distintas dan diseños distintos", different)

local layoutProblems = {}
local function isBorder(cell, size)
	return cell.row == 1 or cell.row == size or cell.col == 1 or cell.col == size
end
for seed = 1, 200 do
	local layout = MapGrid.generate(seed, MapConfig)
	local size = layout.size
	local buildings, bunkers, plazas = 0, 0, 0
	for _, id in layout.cells do
		if id == "House" or id == "GasStation" then
			buildings += 1
		elseif id == "Bunker" then
			bunkers += 1
		end
	end
	if #layout.cells ~= size * size then
		table.insert(layoutProblems, `semilla {seed}: tamaño`)
	elseif bunkers ~= 1 or layout.cells[MapGrid.index(size, layout.bunkerCell.row, layout.bunkerCell.col)] ~= "Bunker" then
		table.insert(layoutProblems, `semilla {seed}: búnker`)
	elseif not isBorder(layout.bunkerCell, size) or not isBorder(layout.startCell, size) then
		table.insert(layoutProblems, `semilla {seed}: bordes`)
	elseif buildings < MapConfig.MIN_BUILDINGS then
		table.insert(layoutProblems, `semilla {seed}: {buildings} edificios`)
	elseif MapGrid.zoneDistance(layout.bunkerCell, layout.startCell) < size - 1 then
		table.insert(layoutProblems, `semilla {seed}: partida y búnker no están en bordes opuestos`)
	end
end
check("200 semillas: 1 búnker en un borde, partida en el borde opuesto, 6+ edificios", #layoutProblems == 0, table.concat(layoutProblems, "; "))

-- Mapa construido ------------------------------------------------------------------------------
section("Mapa construido")
local before = snapshot()
local startedAt = os.clock()
local infoA = MapService:Generate(777)
local generateSeconds = os.clock() - startedAt
check("generar el mapa tarda menos de 3 segundos", generateSeconds < 3, string.format("%.2f s", generateSeconds))
check("el mapa queda en Workspace.GeneratedMap", workspace:FindFirstChild("GeneratedMap") == infoA.folder)
check("MapInfo trae al menos 4 spawns de jugador", #infoA.playerSpawns >= 4, tostring(#infoA.playerSpawns))
check("MapInfo trae al menos 6 sitios de pieza", #infoA.partPoints >= 6, tostring(#infoA.partPoints))
check("MapInfo trae spawns de infectado", #infoA.zombieSpawns >= 1, tostring(#infoA.zombieSpawns))
check("MapInfo trae la puerta, su posición y el interior del búnker", infoA.bunker ~= nil and infoA.bunker.door ~= nil and infoA.bunker.interior ~= nil and (infoA.bunker.doorPosition - infoA.bunker.door.Position).Magnitude < 0.01)
check("la puerta del búnker tiene la etiqueta BunkerDoor", infoA.bunker ~= nil and CollectionService:HasTag(infoA.bunker.door, "BunkerDoor"))
check("MapService:GetCurrent devuelve el mapa generado", MapService:GetCurrent() == infoA)

local zoneFolders = 0
for _, child in infoA.folder:GetChildren() do
	if child:IsA("Folder") then
		zoneFolders += 1
	end
end
check("hay una zona por celda de la cuadrícula", zoneFolders == MapConfig.GRID_SIZE * MapConfig.GRID_SIZE, tostring(zoneFolders))

-- Determinismo: misma semilla = mismo MapInfo.
local infoB = MapService:Generate(777)
check("la misma semilla da los mismos spawns de jugador", vectorsEqual(infoA.playerSpawns, infoB.playerSpawns))
check("la misma semilla da los mismos spawns de infectado", vectorsEqual(infoA.zombieSpawns, infoB.zombieSpawns))
check("la misma semilla da los mismos sitios de pieza", vectorsEqual(infoA.partPoints, infoB.partPoints))
check("la misma semilla da la misma puerta", (infoA.bunker.doorPosition - infoB.bunker.doorPosition).Magnitude < 0.01)
local infoC = MapService:Generate(778)
check("otra semilla da otro mapa", not vectorsEqual(infoB.partPoints, infoC.partPoints) or not vectorsEqual(infoB.playerSpawns, infoC.playerSpawns))
local infoD = MapService:Generate(777)

-- Ningún punto cae dentro de una pared ni bajo el suelo.
local function solidAt(position: Vector3, size: Vector3)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { infoD.folder }
	for _, hit in workspace:GetPartBoundsInBox(CFrame.new(position), size, params) do
		if hit.CanCollide then
			return hit
		end
	end
	return nil
end
local badSpawns, badParts = {}, {}
for i, point in infoD.playerSpawns do
	if solidAt(point, Vector3.new(2, 4, 2)) then
		table.insert(badSpawns, i)
	end
end
for i, point in infoD.partPoints do
	if solidAt(point, Vector3.new(2, 2, 2)) then
		table.insert(badParts, i)
	end
end
check("ningún spawn de jugador cae dentro de una pared o bajo el suelo", #badSpawns == 0, table.concat(badSpawns, ","))
check("ningún sitio de pieza cae dentro de una pared o bajo el suelo", #badParts == 0, table.concat(badParts, ","))

-- Los infectados no aparecen cerca de los jugadores.
local minDistance = math.huge
for _, zombiePoint in infoD.zombieSpawns do
	for _, playerPoint in infoD.playerSpawns do
		minDistance = math.min(minDistance, (zombiePoint - playerPoint).Magnitude)
	end
end
check("cada spawn de infectado está a más de una zona de los de jugador", minDistance > MapConfig.ZONE_SIZE, string.format("%.1f studs", minDistance))

-- Camino desde la zona de partida hasta la puerta del búnker, en varias semillas.
section("Caminos")
local pathProblems = {}
for seed = 1, 10 do
	local info = MapService:Generate(seed * 31)
	local front = info.bunker.doorPosition - info.bunker.door.CFrame.LookVector * 6
	local path = PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
	local ok, err = pcall(path.ComputeAsync, path, info.playerSpawns[1], Vector3.new(front.X, info.playerSpawns[1].Y, front.Z))
	if not ok or path.Status ~= Enum.PathStatus.Success then
		table.insert(pathProblems, `semilla {seed * 31}: {ok and tostring(path.Status) or tostring(err)}`)
	end
end
check("hay camino caminable de la partida a la puerta del búnker en 10 semillas", #pathProblems == 0, table.concat(pathProblems, "; "))

-- Limpieza ------------------------------------------------------------------------------------------
section("Limpiar")
MapService:Clear()
check("Clear borra el mapa", workspace:FindFirstChild("GeneratedMap") == nil and MapService:GetCurrent() == nil)
check("Clear no deja puntos de botín del mapa", #CollectionService:GetTagged("BunkerDoor") == 0)
check("Clear no deja instancias nuevas en el Workspace", leftovers(before) == 0, `sobran {leftovers(before)}`)

for _ = 1, 20 do
	MapService:Generate(math.random(1, 100000))
	MapService:Clear()
end
check("generar y limpiar 20 veces no deja instancias sueltas", leftovers(before) == 0, `sobran {leftovers(before)}`)

print(`[TestMapa] RESULTADO MAPA: {passed} PASS, {failed} FAIL`)
