--!nonstrict
-- LootService
-- Reparte botín en los puntos con la etiqueta "LootPoint" según su tabla (atributo LootTable).
-- En Studio, si el mapa no tiene ningún punto, crea una casa de prueba (Dev/DevHouse).
-- Más adelante MatchService llamará a PopulateAll() al empezar cada partida.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Loot = require(Shared.Config.Loot)
local Weighted = require(Shared.Util.Weighted)

local LootService = {}

local rng = Random.new()

-- Tira los dados para una tabla de botín. Devuelve id y cantidad, o nil si el punto sale vacío.
-- Recibe el Random para poder probarse con semilla fija.
function LootService.rollEntry(tableName: string, random: Random)
	local lootTable = Loot[tableName]
	if not lootTable then
		return nil, 0
	end
	if random:NextNumber() > lootTable.chance then
		return nil, 0
	end
	local entry = Weighted.pick(lootTable.entries, random)
	local count = random:NextInteger(entry.count[1], entry.count[2])
	return entry.id, count
end

function LootService:PopulatePoint(point: BasePart): boolean
	local InventoryService = require(script.Parent.InventoryService)
	local tableName = point:GetAttribute("LootTable") or "House"
	local id, count = LootService.rollEntry(tableName, rng)
	if not id then
		return false
	end
	InventoryService:SpawnPickup(point.Position, id, count)
	return true
end

function LootService:PopulateAll(): number
	local spawned = 0
	for _, point in CollectionService:GetTagged("LootPoint") do
		if point:IsA("BasePart") and LootService:PopulatePoint(point) then
			spawned += 1
		end
	end
	return spawned
end

function LootService:Init() end

function LootService:Start()
	if #CollectionService:GetTagged("LootPoint") == 0 and RunService:IsStudio() then
		local DevHouse = require(script.Parent.Parent.Dev.DevHouse)
		DevHouse.build(Vector3.new(40, 0, 0))
	end
	local spawned = LootService:PopulateAll()
	print(`[LootService] Botín generado: {spawned}`)
end

return LootService
