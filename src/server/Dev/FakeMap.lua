--!nonstrict
-- FakeMap
-- Mapa de mentira para probar MatchService y las oleadas mientras no exista el
-- MapService real de Axel (docs/plan-semana-3.md). Devuelve un MapInfo con la misma
-- forma que debe devolver MapService:Generate(seed):
--   playerSpawns  lista de Vector3 (al menos 4)
--   zombieSpawns  lista de Vector3
--   partPoints    lista de Vector3 (al menos 6)
--   bunker        { door = Part, doorPosition = Vector3, interior = Part }
-- No está en la carpeta Services, así que Main no lo carga como servicio.
-- MatchService lo usa solo si MapService todavía no tiene la función Generate.

local FakeMap = {}

-- Lejos de la casa de prueba y del punto de inicio, dentro del Baseplate (±256).
local CENTER = Vector3.new(-150, 0, -150)

local currentFolder = nil

function FakeMap.clear()
	if currentFolder then
		currentFolder:Destroy()
		currentFolder = nil
	end
end

function FakeMap.generate(seed: number?)
	FakeMap.clear()
	local rng = Random.new(seed or 0)

	local folder = Instance.new("Folder")
	folder.Name = "FakeMatchMap"
	folder.Parent = workspace
	currentFolder = folder

	-- 4 puntos de aparición juntos, en cruz alrededor del centro.
	local playerSpawns = {}
	for i = 1, 4 do
		local angle = (i - 1) * math.pi / 2
		table.insert(playerSpawns, CENTER + Vector3.new(math.cos(angle) * 8, 3, math.sin(angle) * 8))
	end

	-- 8 puntos para infectados en un anillo ancho.
	local zombieSpawns = {}
	for i = 1, 8 do
		local angle = (i - 1) * math.pi / 4 + rng:NextNumber(-0.1, 0.1)
		table.insert(zombieSpawns, CENTER + Vector3.new(math.cos(angle) * 90, 3, math.sin(angle) * 90))
	end

	-- 6 sitios repartidos para esconder las piezas del búnker.
	local partPoints = {}
	for i = 1, 6 do
		local angle = (i - 1) * math.pi / 3 + rng:NextNumber(-0.2, 0.2)
		local radius = rng:NextNumber(35, 70)
		table.insert(partPoints, CENTER + Vector3.new(math.cos(angle) * radius, 2, math.sin(angle) * radius))
	end

	-- Búnker: una puerta y una zona de interior (invisible, sin colisión) detrás.
	local doorPosition = CENTER + Vector3.new(0, 5, 110)
	local door = Instance.new("Part")
	door.Name = "BunkerDoor"
	door.Size = Vector3.new(12, 10, 1)
	door.Position = doorPosition
	door.Anchored = true
	door.Material = Enum.Material.Metal
	door.Color = Color3.fromRGB(70, 75, 80)
	door.Parent = folder

	local interior = Instance.new("Part")
	interior.Name = "BunkerInterior"
	interior.Size = Vector3.new(16, 8, 14)
	interior.Position = CENTER + Vector3.new(0, 4, 122)
	interior.Anchored = true
	interior.CanCollide = false
	interior.CanQuery = false
	interior.CanTouch = false
	interior.Transparency = 0.85
	interior.Color = Color3.fromRGB(80, 160, 90)
	interior.Parent = folder

	return {
		playerSpawns = playerSpawns,
		zombieSpawns = zombieSpawns,
		partPoints = partPoints,
		bunker = { door = door, doorPosition = doorPosition, interior = interior },
	}
end

return FakeMap
