--!nonstrict
-- Diseño de la cuadrícula del mapa. Lógica pura (sin Instances): la misma semilla da
-- siempre el mismo diseño, y se puede probar sin construir nada.
--
-- Filas y columnas empiezan en 1. La fila 1 es el norte (Z menor) y la columna 1 el oeste
-- (X menor). El búnker va en un borde y la zona de partida en el borde opuesto.

local Weighted = require(script.Parent.Weighted)

local MapGrid = {}

-- Por cada lado del borde: cómo se reconoce la celda y hacia dónde mira el interior del mapa.
local SIDES = { "North", "South", "West", "East" }
local OPPOSITE = { North = "South", South = "North", West = "East", East = "West" }
local INWARD = {
	North = Vector3.new(0, 0, 1),
	South = Vector3.new(0, 0, -1),
	West = Vector3.new(1, 0, 0),
	East = Vector3.new(-1, 0, 0),
}

function MapGrid.index(size: number, row: number, col: number): number
	return (row - 1) * size + col
end

-- Celda del borde `side` en la posición `along` (1..size) a lo largo de ese borde.
local function edgeCell(size: number, side: string, along: number)
	if side == "North" then
		return { row = 1, col = along }
	elseif side == "South" then
		return { row = size, col = along }
	elseif side == "West" then
		return { row = along, col = 1 }
	end
	return { row = along, col = size }
end

-- Hacia dónde mira el interior del mapa desde un borde (vector unitario en el plano XZ).
function MapGrid.inwardDirection(side: string): Vector3
	return INWARD[side]
end

-- Distancia en zonas (Chebyshev) entre dos celdas.
function MapGrid.zoneDistance(a, b): number
	return math.max(math.abs(a.row - b.row), math.abs(a.col - b.col))
end

-- Devuelve:
--   seed, size
--   cells: lista de ids de módulo, fila por fila (usa MapGrid.index)
--   startCell, bunkerCell: { row, col }
--   bunkerSide: borde donde está el búnker ("North", "South", "West" o "East")
function MapGrid.generate(seed: number, config)
	local size = config.GRID_SIZE
	local random = Random.new(seed)

	local bunkerSide = SIDES[random:NextInteger(1, #SIDES)]
	local bunkerCell = edgeCell(size, bunkerSide, random:NextInteger(1, size))
	local startCell = edgeCell(size, OPPOSITE[bunkerSide], random:NextInteger(1, size))

	local buildingIds = {}
	for _, module in config.MODULES do
		buildingIds[module.id] = module.isBuilding
	end

	local cells = {}
	for row = 1, size do
		for col = 1, size do
			local id
			if row == bunkerCell.row and col == bunkerCell.col then
				id = "Bunker"
			elseif row == startCell.row and col == startCell.col then
				id = "Plaza"
			else
				id = Weighted.pick(config.MODULES, random).id
			end
			cells[MapGrid.index(size, row, col)] = id
		end
	end

	-- Garantiza los edificios mínimos convirtiendo celdas libres (ni búnker ni partida).
	local buildings = 0
	local convertible = {}
	for i, id in cells do
		if buildingIds[id] then
			buildings += 1
		elseif id ~= "Bunker" and i ~= MapGrid.index(size, startCell.row, startCell.col) then
			table.insert(convertible, i)
		end
	end
	local buildingChoices = {}
	for _, module in config.MODULES do
		if module.isBuilding then
			table.insert(buildingChoices, module)
		end
	end
	while buildings < config.MIN_BUILDINGS and #convertible > 0 do
		local pick = random:NextInteger(1, #convertible)
		cells[convertible[pick]] = Weighted.pick(buildingChoices, random).id
		table.remove(convertible, pick)
		buildings += 1
	end

	return {
		seed = seed,
		size = size,
		cells = cells,
		startCell = startCell,
		bunkerCell = bunkerCell,
		bunkerSide = bunkerSide,
	}
end

-- Centro de una celda en el mundo (y = 0), con la esquina del mapa en `origin`.
function MapGrid.cellCenter(origin: Vector3, zoneSize: number, row: number, col: number): Vector3
	return origin + Vector3.new((col - 0.5) * zoneSize, 0, (row - 0.5) * zoneSize)
end

return MapGrid
