--!nonstrict
-- Piezas básicas para armar los módulos del mapa. Todo se coloca con un CFrame base
-- (el de la zona o el del edificio) más un desplazamiento local; el frente es +Z local.

local CollectionService = game:GetService("CollectionService")

local MapBuild = {}

MapBuild.COLORS = {
	Asphalt = Color3.fromRGB(55, 57, 60),
	Concrete = Color3.fromRGB(120, 115, 105),
	DarkConcrete = Color3.fromRGB(80, 75, 70),
	Grass = Color3.fromRGB(70, 90, 60),
	Dirt = Color3.fromRGB(95, 80, 60),
	Roof = Color3.fromRGB(70, 60, 55),
	Metal = Color3.fromRGB(110, 118, 125),
	Trunk = Color3.fromRGB(80, 60, 45),
	Leaves = Color3.fromRGB(45, 75, 45),
	Rust = Color3.fromRGB(125, 70, 50),
}

-- Parte anclada colocada en `base * offset`. options: material, shape, transparency,
-- collide, rotation (CFrame extra aplicado después del desplazamiento).
function MapBuild.part(parent: Instance, name: string, size: Vector3, base: CFrame, offset: Vector3, color: Color3, options)
	options = options or {}
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.Color = color
	part.Material = options.material or Enum.Material.Concrete
	if options.shape then
		part.Shape = options.shape
	end
	part.CFrame = base * CFrame.new(offset) * (options.rotation or CFrame.identity)
	if options.transparency then
		part.Transparency = options.transparency
	end
	if options.collide == false then
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
	end
	part.Parent = parent
	return part
end

-- Punto de botín invisible, con la etiqueta LootPoint y su tabla. Devuelve la parte.
function MapBuild.lootPoint(parent: Instance, name: string, base: CFrame, offset: Vector3, tableName: string)
	local point = MapBuild.part(parent, name, Vector3.new(1, 1, 1), base, offset, Color3.new(1, 1, 1), {
		transparency = 1,
		collide = false,
	})
	point:SetAttribute("LootTable", tableName)
	CollectionService:AddTag(point, "LootPoint")
	return point
end

-- Cuatro paredes de un edificio de ancho x fondo, centrado en `base`, con una puerta de
-- `doorWidth` en la pared del frente (+Z). Altura `height`. Devuelve nada; las partes
-- cuelgan de `parent`.
function MapBuild.walls(parent: Instance, base: CFrame, width: number, depth: number, height: number, doorWidth: number, color: Color3)
	local half = height / 2
	local doorHeight = height - 3
	local sideWidth = (width - doorWidth) / 2
	MapBuild.part(parent, "WallBack", Vector3.new(width, height, 1), base, Vector3.new(0, half, -depth / 2), color)
	MapBuild.part(parent, "WallLeft", Vector3.new(1, height, depth), base, Vector3.new(-width / 2, half, 0), color)
	MapBuild.part(parent, "WallRight", Vector3.new(1, height, depth), base, Vector3.new(width / 2, half, 0), color)
	MapBuild.part(parent, "WallFrontLeft", Vector3.new(sideWidth, height, 1), base, Vector3.new(-(doorWidth + sideWidth) / 2, half, depth / 2), color)
	MapBuild.part(parent, "WallFrontRight", Vector3.new(sideWidth, height, 1), base, Vector3.new((doorWidth + sideWidth) / 2, half, depth / 2), color)
	MapBuild.part(parent, "DoorLintel", Vector3.new(doorWidth, 3, 1), base, Vector3.new(0, doorHeight + 1.5, depth / 2), color)
end

-- Suelo y techo de un edificio (el suelo sube 0.2 sobre la calle para marcar la entrada).
function MapBuild.floorAndRoof(parent: Instance, base: CFrame, width: number, depth: number, height: number, floorColor: Color3, roofColor: Color3)
	MapBuild.part(parent, "Floor", Vector3.new(width, 0.4, depth), base, Vector3.new(0, 0.2, 0), floorColor)
	MapBuild.part(parent, "Roof", Vector3.new(width + 2, 1, depth + 2), base, Vector3.new(0, height + 0.5, 0), roofColor)
end

-- Convierte un desplazamiento local de `base` en una posición del mundo.
function MapBuild.toWorld(base: CFrame, offset: Vector3): Vector3
	return (base * CFrame.new(offset)).Position
end

return MapBuild
