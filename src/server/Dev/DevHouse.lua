--!nonstrict
-- Casa de prueba hecha con partes simples, solo para desarrollo en Studio.
-- No está en la carpeta Services, así que Main no la carga como servicio.
-- Los puntos de botín llevan la etiqueta "LootPoint" y el atributo LootTable.

local CollectionService = game:GetService("CollectionService")

local DevHouse = {}

local function makePart(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Anchored = true
	part.Material = Enum.Material.Concrete
	part.Color = color
	part.Parent = parent
	return part
end

function DevHouse.build(origin: Vector3)
	local folder = Instance.new("Folder")
	folder.Name = "DevHouse"
	folder.Parent = workspace

	local wall = Color3.fromRGB(120, 115, 105)
	local floorColor = Color3.fromRGB(80, 70, 60)

	makePart(folder, "Floor", Vector3.new(24, 1, 24), origin + Vector3.new(0, 0.5, 0), floorColor)
	makePart(folder, "WallBack", Vector3.new(24, 10, 1), origin + Vector3.new(0, 6, -12), wall)
	makePart(folder, "WallLeft", Vector3.new(1, 10, 24), origin + Vector3.new(-12, 6, 0), wall)
	makePart(folder, "WallRight", Vector3.new(1, 10, 24), origin + Vector3.new(12, 6, 0), wall)
	makePart(folder, "WallFrontLeft", Vector3.new(9, 10, 1), origin + Vector3.new(-7.5, 6, 12), wall)
	makePart(folder, "WallFrontRight", Vector3.new(9, 10, 1), origin + Vector3.new(7.5, 6, 12), wall)
	makePart(folder, "DoorLintel", Vector3.new(6, 3, 1), origin + Vector3.new(0, 9.5, 12), wall)
	makePart(folder, "Roof", Vector3.new(26, 1, 26), origin + Vector3.new(0, 11.5, 0), floorColor)

	local spots = {
		Vector3.new(-8, 1.5, -8),
		Vector3.new(0, 1.5, -8),
		Vector3.new(8, 1.5, -8),
		Vector3.new(-8, 1.5, 2),
		Vector3.new(8, 1.5, 2),
		Vector3.new(0, 1.5, 6),
	}
	for i, offset in spots do
		local point = Instance.new("Part")
		point.Name = `LootPoint{i}`
		point.Size = Vector3.new(1, 1, 1)
		point.Position = origin + offset
		point.Anchored = true
		point.CanCollide = false
		point.CanQuery = false
		point.Transparency = 1
		point:SetAttribute("LootTable", "House")
		point.Parent = folder
		CollectionService:AddTag(point, "LootPoint")
	end

	return folder
end

return DevHouse
