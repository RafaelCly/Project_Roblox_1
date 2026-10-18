--!nonstrict
-- Constructores de los módulos del mapa. Cada uno recibe un contexto
--   { folder, base, random, lotSize }
-- (`base` es el CFrame del centro de la zona sobre el suelo, con +Z mirando al interior del
-- mapa en la zona del búnker) y devuelve
--   { lotColor, partSlots = { Vector3 }, extra... }
-- Las calles que rodean la zona las pone MapService: los módulos solo usan el solar interior
-- (`lotSize`), así siempre queda un camino libre alrededor de cada zona.

local MapBuild = require(script.Parent.MapBuild)

local part, lootPoint, walls, floorAndRoof, toWorld = MapBuild.part, MapBuild.lootPoint, MapBuild.walls, MapBuild.floorAndRoof, MapBuild.toWorld
local COLORS = MapBuild.COLORS

local MapModules = {}

-- Base de un edificio dentro del solar: desplazado un poco al azar y girado a un múltiplo
-- de 90° para que la puerta mire a un lado distinto cada vez.
local function randomBuildingBase(ctx, maxShift: number)
	local shiftX = ctx.random:NextNumber(-maxShift, maxShift)
	local shiftZ = ctx.random:NextNumber(-maxShift, maxShift)
	local quarterTurns = ctx.random:NextInteger(0, 3)
	return ctx.base * CFrame.new(shiftX, 0, shiftZ) * CFrame.Angles(0, quarterTurns * math.pi / 2, 0)
end

-- Casa: una sola planta de 26 x 22, con una puerta y 5 puntos de botín.
function MapModules.House(ctx)
	local building = Instance.new("Folder")
	building.Name = "House"
	building.Parent = ctx.folder
	local base = randomBuildingBase(ctx, 8)
	local width, depth, height = 26, 22, 10

	floorAndRoof(building, base, width, depth, height, COLORS.DarkConcrete, COLORS.Roof)
	walls(building, base, width, depth, height, 6, COLORS.Concrete)

	local spots = {
		Vector3.new(-9, 1.5, -7),
		Vector3.new(0, 1.5, -7),
		Vector3.new(9, 1.5, -7),
		Vector3.new(-9, 1.5, 3),
		Vector3.new(9, 1.5, 3),
	}
	for i, offset in spots do
		lootPoint(building, `LootPoint{i}`, base, offset, "House")
	end
	return { lotColor = COLORS.Dirt, partSlots = { toWorld(base, Vector3.new(0, 1.5, 0)) } }
end

-- Gasolinera: tienda con puerta, marquesina con dos surtidores y botín dentro y fuera.
function MapModules.GasStation(ctx)
	local station = Instance.new("Folder")
	station.Name = "GasStation"
	station.Parent = ctx.folder
	local base = randomBuildingBase(ctx, 4)

	-- Tienda al fondo (-Z local), mirando al frente (+Z).
	local shopBase = base * CFrame.new(0, 0, -10)
	local shopWidth, shopDepth, shopHeight = 18, 12, 9
	floorAndRoof(station, shopBase, shopWidth, shopDepth, shopHeight, COLORS.DarkConcrete, COLORS.Roof)
	walls(station, shopBase, shopWidth, shopDepth, shopHeight, 6, COLORS.Concrete)
	for i, offset in { Vector3.new(-6, 1.5, -3), Vector3.new(6, 1.5, -3), Vector3.new(0, 1.5, 2) } do
		lootPoint(station, `ShopLoot{i}`, shopBase, offset, "GasStation")
	end

	-- Marquesina delante de la tienda, sobre cuatro postes, con dos surtidores.
	local canopyBase = base * CFrame.new(0, 0, 10)
	for i, offset in { Vector3.new(-10, 5.5, -5), Vector3.new(10, 5.5, -5), Vector3.new(-10, 5.5, 5), Vector3.new(10, 5.5, 5) } do
		part(station, `Pillar{i}`, Vector3.new(1.5, 11, 1.5), canopyBase, offset, COLORS.Metal)
	end
	part(station, "Canopy", Vector3.new(24, 1, 14), canopyBase, Vector3.new(0, 11.5, 0), COLORS.Rust)
	for i, x in { -5, 5 } do
		part(station, `Pump{i}`, Vector3.new(2, 4, 3), canopyBase, Vector3.new(x, 2, 0), COLORS.Metal)
		lootPoint(station, `PumpLoot{i}`, canopyBase, Vector3.new(x, 1.5, 3), "GasStation")
	end

	return { lotColor = COLORS.Asphalt, partSlots = { toWorld(shopBase, Vector3.new(0, 1.5, 0)) } }
end

-- Bosque: árboles repartidos por el solar (sin tocar las calles) y dos puntos de botín.
function MapModules.Forest(ctx)
	local forest = Instance.new("Folder")
	forest.Name = "Forest"
	forest.Parent = ctx.folder
	local range = ctx.lotSize / 2 - 3
	local treeCount = ctx.random:NextInteger(14, 20)
	for i = 1, treeCount do
		local x = ctx.random:NextNumber(-range, range)
		local z = ctx.random:NextNumber(-range, range)
		local trunkHeight = ctx.random:NextNumber(7, 10)
		local crown = ctx.random:NextNumber(7, 11)
		part(forest, `Trunk{i}`, Vector3.new(trunkHeight, 1.6, 1.6), ctx.base, Vector3.new(x, trunkHeight / 2, z), COLORS.Trunk, {
			shape = Enum.PartType.Cylinder,
			material = Enum.Material.Wood,
			rotation = CFrame.Angles(0, 0, math.pi / 2),
		})
		part(forest, `Crown{i}`, Vector3.new(crown, crown, crown), ctx.base, Vector3.new(x, trunkHeight + crown / 3, z), COLORS.Leaves, {
			shape = Enum.PartType.Ball,
			material = Enum.Material.Grass,
		})
	end
	for i = 1, 2 do
		local x = ctx.random:NextNumber(-range, range)
		local z = ctx.random:NextNumber(-range, range)
		lootPoint(forest, `ForestLoot{i}`, ctx.base, Vector3.new(x, 1.5, z), "Forest")
	end
	return { lotColor = COLORS.Grass, partSlots = {} }
end

-- Plaza: solar abierto con algunos coches abandonados y cajas. Es también la zona de partida.
function MapModules.Plaza(ctx)
	local plaza = Instance.new("Folder")
	plaza.Name = "Plaza"
	plaza.Parent = ctx.folder
	local range = ctx.lotSize / 2 - 6
	local carCount = ctx.random:NextInteger(3, 5)
	for i = 1, carCount do
		local x = ctx.random:NextNumber(-range, range)
		local z = ctx.random:NextNumber(-range, range)
		local turn = ctx.random:NextInteger(0, 3) * math.pi / 2
		local carBase = ctx.base * CFrame.new(x, 0, z) * CFrame.Angles(0, turn, 0)
		part(plaza, `CarBody{i}`, Vector3.new(4, 1.6, 8), carBase, Vector3.new(0, 1.4, 0), COLORS.Rust, { material = Enum.Material.Metal })
		part(plaza, `CarCabin{i}`, Vector3.new(3.4, 1.4, 4), carBase, Vector3.new(0, 2.9, -0.5), COLORS.Metal, { material = Enum.Material.Metal })
	end
	return { lotColor = COLORS.Concrete, partSlots = {} }
end

-- Búnker: edificio de hormigón con una puerta de acero en el frente (+Z, mira al interior del
-- mapa) y una parte invisible que marca el interior. La puerta es una Parte con la etiqueta
-- BunkerDoor; quien abra la puerta solo tiene que quitarle la colisión o moverla.
function MapModules.Bunker(ctx)
	local bunker = Instance.new("Folder")
	bunker.Name = "Bunker"
	bunker.Parent = ctx.folder
	local base = ctx.base
	local width, depth, height, doorWidth = 30, 24, 12, 8

	floorAndRoof(bunker, base, width, depth, height, COLORS.DarkConcrete, COLORS.Roof)
	-- Las paredes dejan el hueco de la puerta; la puerta lo rellena.
	walls(bunker, base, width, depth, height, doorWidth, COLORS.DarkConcrete)
	local door = part(bunker, "BunkerDoor", Vector3.new(doorWidth, height - 3, 1), base, Vector3.new(0, (height - 3) / 2, depth / 2), COLORS.Metal, { material = Enum.Material.Metal })
	game:GetService("CollectionService"):AddTag(door, "BunkerDoor")
	local interior = part(bunker, "BunkerInterior", Vector3.new(width - 4, 8, depth - 4), base, Vector3.new(0, 4, 0), Color3.new(1, 1, 1), {
		transparency = 1,
		collide = false,
	})
	return {
		lotColor = COLORS.DarkConcrete,
		partSlots = {},
		bunker = { door = door, doorPosition = door.Position, interior = interior },
	}
end

return MapModules
