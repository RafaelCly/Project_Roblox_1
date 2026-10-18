--!nonstrict
-- MapService
-- Genera el mapa de la partida: una cuadrícula de zonas modulares (calles, casas, gasolinera,
-- bosque, plaza y la zona del búnker) hecha con piezas simples. Misma semilla = mismo mapa.
--   MapService:Generate(seed) -> MapInfo   construye el mapa (borra el anterior)
--   MapService:Clear()                     borra el mapa y todo lo que generó
--   MapService:GetCurrent() -> MapInfo?    el mapa actual, o nil
-- MapInfo: { seed, layout, playerSpawns, zombieSpawns, partPoints, bunker, folder }
-- bunker = { door = Part, doorPosition = Vector3, interior = Part }
-- En Studio, workspace:SetAttribute("DevMap", 12345) genera un mapa y imprime su resumen,
-- y workspace:SetAttribute("DevMapClear", true) lo borra.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapConfig = require(Shared.Config.Map)
local MapGrid = require(Shared.Util.MapGrid)
local MapBuild = require(script.Parent.Parent.Util.MapBuild)
local MapModules = require(script.Parent.Parent.Util.MapModules)

local MAP_FOLDER_NAME = "GeneratedMap"
local MAX_GENERATE_SECONDS = 3 -- el plan pide generar en menos de esto; se avisa si no se cumple

local MapService = {}

local current = nil

-- Las cuatro direcciones hacia los lados de una zona, para repartir puntos por sus calles.
local SIDE_DIRECTIONS = {
	Vector3.new(0, 0, -1),
	Vector3.new(0, 0, 1),
	Vector3.new(-1, 0, 0),
	Vector3.new(1, 0, 0),
}

-- Suelo de una zona: asfalto en toda la zona y un solar interior del color del módulo.
local function buildGround(zoneFolder: Folder, center: Vector3, lotColor: Color3, lotSize: number)
	local base = CFrame.new(center)
	MapBuild.part(zoneFolder, "Street", Vector3.new(MapConfig.ZONE_SIZE, 1, MapConfig.ZONE_SIZE), base, Vector3.new(0, -0.5, 0), MapBuild.COLORS.Asphalt, {
		material = Enum.Material.Asphalt,
	})
	MapBuild.part(zoneFolder, "Lot", Vector3.new(lotSize, 0.2, lotSize), base, Vector3.new(0, 0.1, 0), lotColor, {
		material = Enum.Material.Ground,
	})
end

-- Puntos de aparición de los jugadores: una fila sobre la calle exterior de la zona de partida.
local function playerSpawnPoints(layout, startCenter: Vector3): { Vector3 }
	local inward = MapGrid.inwardDirection(layout.bunkerSide)
	-- La zona de partida está en el borde opuesto al búnker, así que su exterior mira hacia
	-- donde mira el interior del búnker.
	local outward = inward
	local streetCenter = startCenter + outward * (MapConfig.ZONE_SIZE / 2 - MapConfig.STREET_WIDTH / 2)
	local along = Vector3.new(math.abs(outward.Z), 0, math.abs(outward.X))
	local spacing = 6
	local points = {}
	local first = -(MapConfig.PLAYER_SPAWNS - 1) / 2 * spacing
	for i = 1, MapConfig.PLAYER_SPAWNS do
		table.insert(points, streetCenter + along * (first + (i - 1) * spacing) + Vector3.new(0, MapConfig.SPAWN_HEIGHT, 0))
	end
	return points
end

-- Puntos de aparición de infectados: sobre las calles de las zonas lejanas a la de partida.
local function zombieSpawnPoints(layout, centers, zoneRandoms): { Vector3 }
	local points = {}
	local half = MapConfig.ZONE_SIZE / 2 - MapConfig.STREET_WIDTH / 2
	for row = 1, layout.size do
		for col = 1, layout.size do
			local cell = { row = row, col = col }
			local isBunker = row == layout.bunkerCell.row and col == layout.bunkerCell.col
			if not isBunker and MapGrid.zoneDistance(cell, layout.startCell) >= MapConfig.ZOMBIE_MIN_ZONE_DISTANCE then
				local index = MapGrid.index(layout.size, row, col)
				local random = zoneRandoms[index]
				for _ = 1, MapConfig.ZOMBIE_SPAWNS_PER_ZONE do
					local direction = SIDE_DIRECTIONS[random:NextInteger(1, #SIDE_DIRECTIONS)]
					local along = Vector3.new(math.abs(direction.Z), 0, math.abs(direction.X))
					local offset = direction * half + along * random:NextNumber(-20, 20)
					table.insert(points, centers[index] + offset + Vector3.new(0, MapConfig.SPAWN_HEIGHT, 0))
				end
			end
		end
	end
	return points
end

function MapService:Clear()
	local folder = workspace:FindFirstChild(MAP_FOLDER_NAME)
	if folder then
		folder:Destroy() -- las etiquetas de las partes se van con ellas
	end
	current = nil
end

function MapService:GetCurrent()
	return current
end

function MapService:Generate(seed: number)
	assert(type(seed) == "number", "MapService:Generate necesita una semilla numérica")
	local startedAt = os.clock()
	MapService:Clear()

	local layout = MapGrid.generate(seed, MapConfig)
	local folder = Instance.new("Folder")
	folder.Name = MAP_FOLDER_NAME
	folder:SetAttribute("Seed", seed)

	local lotSize = MapConfig.ZONE_SIZE - MapConfig.STREET_WIDTH * 2
	local centers, zoneRandoms = {}, {}
	local partPoints, bunkerInfo = {}, nil

	for row = 1, layout.size do
		for col = 1, layout.size do
			local index = MapGrid.index(layout.size, row, col)
			local typeId = layout.cells[index]
			local center = MapGrid.cellCenter(MapConfig.ORIGIN, MapConfig.ZONE_SIZE, row, col)
			centers[index] = center
			-- Cada zona usa su propio generador, derivado de la semilla y de su posición.
			local random = Random.new(seed * 1009 + index * 7919)
			zoneRandoms[index] = random

			local zoneFolder = Instance.new("Folder")
			zoneFolder.Name = `Zone_{row}_{col}`
			zoneFolder:SetAttribute("ZoneType", typeId)

			-- +Z local mira al interior del mapa en el búnker; en el resto da igual.
			local base = CFrame.new(center)
			if typeId == "Bunker" then
				local inward = MapGrid.inwardDirection(layout.bunkerSide)
				base = CFrame.lookAt(center, center - inward)
			end

			local built = MapModules[typeId]({ folder = zoneFolder, base = base, random = random, lotSize = lotSize })
			buildGround(zoneFolder, center, built.lotColor, lotSize)
			for _, slot in built.partSlots do
				table.insert(partPoints, slot)
			end
			if built.bunker then
				bunkerInfo = built.bunker
			end
			zoneFolder.Parent = folder
		end
	end

	local startIndex = MapGrid.index(layout.size, layout.startCell.row, layout.startCell.col)
	local info = {
		seed = seed,
		layout = layout,
		playerSpawns = playerSpawnPoints(layout, centers[startIndex]),
		zombieSpawns = zombieSpawnPoints(layout, centers, zoneRandoms),
		partPoints = partPoints,
		bunker = bunkerInfo,
		folder = folder,
	}
	folder.Parent = workspace
	current = info

	local elapsed = os.clock() - startedAt
	if elapsed > MAX_GENERATE_SECONDS then
		warn(`[MapService] Generar el mapa tardó {string.format("%.2f", elapsed)} s (máximo {MAX_GENERATE_SECONDS} s)`)
	end
	return info
end

local function describe(info): string
	local rows = {}
	for row = 1, info.layout.size do
		local names = {}
		for col = 1, info.layout.size do
			table.insert(names, info.layout.cells[MapGrid.index(info.layout.size, row, col)])
		end
		table.insert(rows, table.concat(names, " "))
	end
	return `semilla {info.seed}, búnker {info.layout.bunkerSide}, {#info.playerSpawns} spawns de jugador, {#info.zombieSpawns} de infectado, {#info.partPoints} sitios de pieza\n{table.concat(rows, "\n")}`
end

function MapService:Init() end

function MapService:Start()
	if not RunService:IsStudio() then
		return
	end
	workspace:GetAttributeChangedSignal("DevMap"):Connect(function()
		local seed = workspace:GetAttribute("DevMap")
		if type(seed) ~= "number" then
			return
		end
		workspace:SetAttribute("DevMap", nil)
		local ok, result = pcall(MapService.Generate, MapService, seed)
		if ok then
			print(`[MapService] Mapa generado: {describe(result)}`)
		else
			warn(`[MapService] Error al generar el mapa: {result}`)
		end
	end)
	workspace:GetAttributeChangedSignal("DevMapClear"):Connect(function()
		if workspace:GetAttribute("DevMapClear") then
			workspace:SetAttribute("DevMapClear", nil)
			MapService:Clear()
			print("[MapService] Mapa borrado")
		end
	end)
end

return MapService
