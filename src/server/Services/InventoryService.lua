--!nonstrict
-- InventoryService
-- Inventario por ranuras: recoger, usar, soltar, pasar a un compañero y fabricar.
-- Al morir el jugador suelta todo (el equipo puede recuperarlo).
-- Toda la lógica de ranuras está en shared/Util/InventoryLogic. Aquí solo hay
-- jugadores, objetos del mundo y validación de lo que pide el cliente.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Items = require(Shared.Config.Items)
local Recipes = require(Shared.Config.Recipes)
local RunConfig = require(Shared.Config.Run)
local SurvivalConfig = require(Shared.Config.Survival)
local InventoryLogic = require(Shared.Util.InventoryLogic)

local InventoryService = {}

local inventories = {} -- [Player] = inventario
local pickupFolder = nil
local rng = Random.new()

local KIND_COLORS = {
	Weapon = Color3.fromRGB(200, 70, 70),
	Ammo = Color3.fromRGB(220, 180, 60),
	Food = Color3.fromRGB(110, 180, 90),
	Heal = Color3.fromRGB(240, 240, 240),
	Material = Color3.fromRGB(150, 130, 100),
	Trap = Color3.fromRGB(90, 140, 200),
}

local function getSurvival()
	return require(script.Parent.SurvivalService)
end

local function getCombat()
	return require(script.Parent.CombatService)
end

local function notify(player: Player, text: string)
	Remotes.get("Notify"):FireClient(player, text)
end

local function push(player: Player)
	local inv = inventories[player]
	if inv then
		-- Si el arma equipada salió del inventario, se desequipa.
		getCombat():SyncWithInventory(player)
		Remotes.get("InventoryChanged"):FireClient(player, InventoryLogic.serialize(inv))
	end
end

local function validSlot(inv, slot): boolean
	return typeof(slot) == "number" and slot % 1 == 0 and slot >= 1 and slot <= inv.slotCount
end

-- Busca el suelo bajo una posición para que los objetos no floten.
local function groundPosition(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { pickupFolder }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(position + Vector3.new(0, 3, 0), Vector3.new(0, -60, 0), params)
	local y = result and result.Position.Y or position.Y
	return Vector3.new(position.X, y + 0.8, position.Z)
end

-- API pública -------------------------------------------------------------

function InventoryService:Get(player: Player)
	return inventories[player]
end

function InventoryService:Count(player: Player, id: string): number
	local inv = inventories[player]
	return inv and InventoryLogic.count(inv, id) or 0
end

-- Devuelve el sobrante que no cupo.
-- durability (opcional): desgaste de un arma que ya se usó.
function InventoryService:AddItem(player: Player, id: string, count: number, durability: number?): number
	local inv = inventories[player]
	if not inv then
		return count
	end
	local leftover = InventoryLogic.add(inv, id, count, durability)
	push(player)
	return leftover
end

function InventoryService:RemoveItem(player: Player, id: string, count: number): boolean
	local inv = inventories[player]
	if not inv then
		return false
	end
	local ok = InventoryLogic.remove(inv, id, count)
	push(player)
	return ok
end

-- Desgasta el arma `id` del jugador. Devuelve true si se rompió y salió del inventario.
function InventoryService:WearWeapon(player: Player, id: string, amount: number, maxDurability: number): boolean
	local inv = inventories[player]
	if not inv then
		return false
	end
	local _, broken = InventoryLogic.wear(inv, id, amount, maxDurability)
	push(player)
	return broken
end

-- Recoger un objeto del suelo. Lo que no cabe se queda en el suelo.
function InventoryService:_collect(player: Player, pickup: BasePart): boolean
	if not pickup.Parent or pickup:GetAttribute("Taken") then
		return false
	end
	local id = pickup:GetAttribute("ItemId")
	local count = pickup:GetAttribute("Count")
	if not Items[id] or typeof(count) ~= "number" then
		return false
	end

	local durability = pickup:GetAttribute("Durability")
	if typeof(durability) ~= "number" then
		durability = nil
	end

	local leftover = InventoryService:AddItem(player, id, count, durability)
	if leftover >= count then
		notify(player, "Inventario lleno")
		return false
	end
	if leftover == 0 then
		pickup:SetAttribute("Taken", true)
		pickup:Destroy()
	else
		pickup:SetAttribute("Count", leftover)
	end
	return true
end

function InventoryService:SpawnPickup(position: Vector3, id: string, count: number, durability: number?): BasePart
	local config = Items[id]
	assert(config, `Objeto desconocido: {id}`)

	local spread = Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
	local part = Instance.new("Part")
	part.Name = `Pickup_{id}`
	part.Size = Vector3.new(1.2, 1.2, 1.2)
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = KIND_COLORS[config.kind] or Color3.fromRGB(255, 255, 255)
	part.Position = groundPosition(position + spread)
	part:SetAttribute("ItemId", id)
	part:SetAttribute("Count", count)
	part:SetAttribute("Durability", durability)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Recoger"
	prompt.ObjectText = config.displayName
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		InventoryService:_collect(player, part)
	end)

	part.Parent = pickupFolder
	return part
end

function InventoryService:DropAll(player: Player, position: Vector3)
	local inv = inventories[player]
	if not inv then
		return 0
	end
	local dropped = 0
	for i = 1, inv.slotCount do
		local durability = inv.slots[i] and inv.slots[i].durability
		local id, count = InventoryLogic.removeAt(inv, i)
		if id then
			InventoryService:SpawnPickup(position, id, count, durability)
			dropped += 1
		end
	end
	push(player)
	return dropped
end

function InventoryService:DropSlot(player: Player, slot): boolean
	local inv = inventories[player]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not inv or not root or not validSlot(inv, slot) then
		return false
	end
	local durability = inv.slots[slot] and inv.slots[slot].durability
	local id, count = InventoryLogic.removeAt(inv, slot)
	if not id then
		return false
	end
	InventoryService:SpawnPickup(root.Position + root.CFrame.LookVector * 3, id, count, durability)
	push(player)
	return true
end

function InventoryService:UseSlot(player: Player, slot): boolean
	local inv = inventories[player]
	if not inv or not validSlot(inv, slot) then
		return false
	end
	local stack = inv.slots[slot]
	if not stack then
		return false
	end

	local Survival = getSurvival()
	if not Survival:IsAlive(player) then
		return false
	end
	if Survival:IsDowned(player) then
		notify(player, "Estás caído, no puedes usar objetos")
		return false
	end

	local config = Items[stack.id]
	local applied = false
	if config.kind == "Weapon" then
		-- Equipar no gasta el objeto. Usar el arma equipada otra vez la guarda.
		local Combat = getCombat()
		if Combat:GetEquipped(player) == stack.id then
			Combat:Unequip(player)
			return true
		end
		return Combat:Equip(player, stack.id)
	elseif config.kind == "Food" then
		applied = Survival:Feed(player, config.hunger)
		if not applied then
			notify(player, "No tienes hambre")
		end
	elseif config.kind == "Heal" then
		applied = Survival:Heal(player, config.heal)
		if not applied then
			notify(player, "Ya tienes la vida completa")
		end
	else
		notify(player, "No se puede usar ahora")
	end

	if applied then
		InventoryLogic.removeAt(inv, slot, 1)
		push(player)
	end
	return applied
end

function InventoryService:GiveSlot(player: Player, slot, targetUserId): boolean
	local inv = inventories[player]
	if not inv or not validSlot(inv, slot) or typeof(targetUserId) ~= "number" then
		return false
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	local targetInv = target and inventories[target]
	if not target or target == player or not targetInv then
		return false
	end

	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local targetRoot = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	if not root or not targetRoot then
		return false
	end
	if (root.Position - targetRoot.Position).Magnitude > SurvivalConfig.GIVE_MAX_DISTANCE then
		notify(player, "Está muy lejos")
		return false
	end

	local stack = inv.slots[slot]
	if not stack then
		return false
	end
	local leftover = InventoryLogic.add(targetInv, stack.id, stack.count, stack.durability)
	local given = stack.count - leftover
	if given == 0 then
		notify(player, "Su inventario está lleno")
		return false
	end
	InventoryLogic.removeAt(inv, slot, given)
	push(player)
	push(target)
	notify(target, `{player.DisplayName} te dio {Items[stack.id].displayName} x{given}`)
	return true
end

function InventoryService:Craft(player: Player, recipeId): boolean
	local inv = inventories[player]
	local recipe = typeof(recipeId) == "string" and Recipes[recipeId]
	if not inv or not recipe then
		return false
	end
	if not InventoryLogic.canCraft(inv, recipe) then
		notify(player, "Faltan materiales")
		return false
	end

	-- Probar en una copia: si el resultado no cabe, no se gasta nada.
	local copy = InventoryLogic.new(inv.slotCount)
	for i, stack in inv.slots do
		copy.slots[i] = { id = stack.id, count = stack.count, durability = stack.durability }
	end
	for id, needed in recipe.inputs do
		InventoryLogic.remove(copy, id, needed)
	end
	if InventoryLogic.add(copy, recipe.output.id, recipe.output.count) > 0 then
		notify(player, "Inventario lleno")
		return false
	end

	inventories[player] = copy
	push(player)
	return true
end

-- Ciclo de vida -----------------------------------------------------------

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	humanoid.Died:Connect(function()
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			InventoryService:DropAll(player, root.Position)
		end
	end)
end

local function onPlayerAdded(player: Player)
	inventories[player] = InventoryLogic.new(RunConfig.INVENTORY_SLOTS)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
	push(player)
	-- El cliente puede tardar en conectar sus eventos: se reenvía el estado al aparecer.
	player.CharacterAdded:Connect(function()
		task.delay(1.5, push, player)
	end)
end

function InventoryService:Init()
	pickupFolder = workspace:FindFirstChild("Pickups")
	if not pickupFolder then
		pickupFolder = Instance.new("Folder")
		pickupFolder.Name = "Pickups"
		pickupFolder.Parent = workspace
	end
end

function InventoryService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		inventories[player] = nil
	end)

	-- El cliente solo pide. Todo se valida arriba.
	Remotes.get("RequestUseItem").OnServerEvent:Connect(function(player, slot)
		InventoryService:UseSlot(player, slot)
	end)
	Remotes.get("RequestDropItem").OnServerEvent:Connect(function(player, slot)
		InventoryService:DropSlot(player, slot)
	end)
	Remotes.get("RequestGiveItem").OnServerEvent:Connect(function(player, slot, targetUserId)
		InventoryService:GiveSlot(player, slot, targetUserId)
	end)
	Remotes.get("RequestCraft").OnServerEvent:Connect(function(player, recipeId)
		InventoryService:Craft(player, recipeId)
	end)
end

return InventoryService
