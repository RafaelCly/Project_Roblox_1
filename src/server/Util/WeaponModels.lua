--!nonstrict
-- WeaponModels
-- Modelos de armas armados por código con varias piezas simples (sin descargar nada).
--
-- decorate(weaponId, anchor) recibe la pieza "EquippedWeaponVisual" que CombatService ya
-- pegó a la mano. La convierte en un ancla invisible y le cuelga las piezas visibles.
--
-- Las medidas están en "espacio de agarre" (el origen es la palma de la mano):
--   -Z = hacia delante, a lo largo del antebrazo (por donde sale el cañón o la hoja)
--   +Y = arriba, +X = derecha. Unidades en studs.

local WeaponModels = {}

local STEEL = Color3.fromRGB(95, 98, 105)
local DARK_STEEL = Color3.fromRGB(48, 50, 56)
local POLYMER = Color3.fromRGB(32, 33, 36)
local WOOD = Color3.fromRGB(150, 106, 62)
local WOOD_DARK = Color3.fromRGB(110, 76, 44)
local BLADE = Color3.fromRGB(190, 195, 202)
local TAPE = Color3.fromRGB(40, 36, 32)

-- Cada pieza: nombre, tamaño, posición del centro y giro opcional (grados sobre X), color, material.
local MODELS = {
	Pistol = {
		parts = {
			{ "Slide", Vector3.new(0.26, 0.28, 1.15), Vector3.new(0, 0.14, -0.55), nil, DARK_STEEL, Enum.Material.Metal },
			{ "Barrel", Vector3.new(0.13, 0.13, 0.2), Vector3.new(0, 0.14, -1.2), nil, STEEL, Enum.Material.Metal },
			{ "Frame", Vector3.new(0.24, 0.12, 0.8), Vector3.new(0, -0.04, -0.4), nil, POLYMER, Enum.Material.SmoothPlastic },
			-- La empuñadura se inclina hacia atrás por abajo, como en una pistola de verdad.
			{ "Handle", Vector3.new(0.24, 0.62, 0.3), Vector3.new(0, -0.34, -0.04), -15, POLYMER, Enum.Material.SmoothPlastic },
			{ "TriggerGuard", Vector3.new(0.1, 0.05, 0.3), Vector3.new(0, -0.14, -0.32), nil, POLYMER, Enum.Material.SmoothPlastic },
			{ "Trigger", Vector3.new(0.06, 0.13, 0.05), Vector3.new(0, -0.09, -0.24), nil, STEEL, Enum.Material.Metal },
			{ "RearSight", Vector3.new(0.1, 0.07, 0.07), Vector3.new(0, 0.31, -0.06), nil, POLYMER, Enum.Material.SmoothPlastic },
			{ "FrontSight", Vector3.new(0.05, 0.07, 0.06), Vector3.new(0, 0.31, -1.05), nil, POLYMER, Enum.Material.SmoothPlastic },
		},
		muzzle = Vector3.new(0, 0.14, -1.32),
	},
	Bat = {
		parts = {
			{ "Knob", Vector3.new(0.24, 0.24, 0.14), Vector3.new(0, 0, 0.1), nil, WOOD_DARK, Enum.Material.Wood },
			{ "Handle", Vector3.new(0.17, 0.17, 1.0), Vector3.new(0, 0, -0.5), nil, WOOD_DARK, Enum.Material.Wood },
			{ "Grip", Vector3.new(0.19, 0.19, 0.45), Vector3.new(0, 0, -0.35), nil, TAPE, Enum.Material.Fabric },
			-- El bate engrosa hacia la punta en tres tramos.
			{ "Barrel1", Vector3.new(0.27, 0.27, 0.7), Vector3.new(0, 0, -1.35), nil, WOOD, Enum.Material.Wood },
			{ "Barrel2", Vector3.new(0.34, 0.34, 0.8), Vector3.new(0, 0, -2.1), nil, WOOD, Enum.Material.Wood },
			{ "Barrel3", Vector3.new(0.4, 0.4, 0.9), Vector3.new(0, 0, -2.95), nil, WOOD, Enum.Material.Wood },
		},
	},
	Knife = {
		parts = {
			{ "Handle", Vector3.new(0.16, 0.22, 0.62), Vector3.new(0, 0, -0.18), nil, TAPE, Enum.Material.Fabric },
			{ "Pommel", Vector3.new(0.2, 0.26, 0.1), Vector3.new(0, 0, 0.17), nil, DARK_STEEL, Enum.Material.Metal },
			{ "Guard", Vector3.new(0.1, 0.5, 0.09), Vector3.new(0, 0, -0.53), nil, DARK_STEEL, Enum.Material.Metal },
			-- La hoja es ancha en vertical y delgada de lado.
			{ "Blade", Vector3.new(0.05, 0.3, 1.0), Vector3.new(0, 0.04, -1.1), nil, BLADE, Enum.Material.Metal },
			{ "Tip", Vector3.new(0.05, 0.2, 0.28), Vector3.new(0, 0.0, -1.74), nil, BLADE, Enum.Material.Metal },
		},
	},
}

function WeaponModels.has(weaponId: string): boolean
	return MODELS[weaponId] ~= nil
end

-- Cuántas piezas visibles tiene el modelo (para las pruebas automáticas).
function WeaponModels.partCount(weaponId: string): number
	local model = MODELS[weaponId]
	return model and #model.parts or 0
end

-- Convierte `anchor` en un ancla invisible en la palma y le cuelga las piezas del arma.
-- El caller debe haber puesto antes el Weld del ancla en el punto de agarre, sin desplazarlo.
function WeaponModels.decorate(weaponId: string, anchor: BasePart)
	local model = MODELS[weaponId]
	assert(model, `Sin modelo para el arma {tostring(weaponId)}`)

	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1

	for _, spec in model.parts do
		local name, size, position, tilt, color, material = table.unpack(spec)
		local piece = Instance.new("Part")
		piece.Name = name
		piece.Size = size
		piece.Color = color
		piece.Material = material
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.Massless = true

		local weld = Instance.new("Weld")
		weld.Part0 = anchor
		weld.Part1 = piece
		weld.C0 = CFrame.new(position) * CFrame.Angles(math.rad(tilt or 0), 0, 0)
		weld.Parent = piece
		piece.Parent = anchor
	end

	if model.muzzle then
		local muzzle = Instance.new("Attachment")
		muzzle.Name = "Muzzle"
		muzzle.Position = model.muzzle
		muzzle.Parent = anchor
	end
end

return WeaponModels
