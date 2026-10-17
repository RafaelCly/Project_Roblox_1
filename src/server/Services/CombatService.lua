--!nonstrict
-- CombatService
-- Armas del jugador: equipar y mostrar el arma en la mano. Dueño: Axel.
-- Solo hay un arma equipada a la vez. El servidor decide cuál está equipada;
-- el cliente la ve como atributo "EquippedWeapon" del jugador.
-- Cuerpo a cuerpo: Attack valida y golpea en un cono. Pendiente: pistola y munición.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Items = require(Shared.Config.Items)
local Weapons = require(Shared.Config.Weapons)

local CombatService = {}

local VISUAL_NAME = "EquippedWeaponVisual"
local ATTRIBUTE_NAME = "EquippedWeapon"
local MELEE_HALF_ANGLE = 60 -- grados a cada lado de la mirada
local COS_MELEE_HALF_ANGLE = math.cos(math.rad(MELEE_HALF_ANGLE))

-- Piezas simples sin arte final: un bloque largo por arma.
local VISUALS = {
	Knife = { size = Vector3.new(0.2, 0.2, 1.4), color = Color3.fromRGB(170, 175, 180) },
	Bat = { size = Vector3.new(0.45, 0.45, 3), color = Color3.fromRGB(139, 99, 60) },
	Pistol = { size = Vector3.new(0.3, 0.7, 0.9), color = Color3.fromRGB(45, 45, 50) },
}

local equipped = {} -- [Player] = itemId

local function getInventory()
	return require(script.Parent.InventoryService)
end

local function getHand(character: Model?)
	if not character then
		return nil
	end
	return character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
end

local function removeVisual(player: Player)
	local character = player.Character
	local visual = character and character:FindFirstChild(VISUAL_NAME)
	if visual then
		visual:Destroy()
	end
end

-- Pega la pieza del arma a la mano derecha.
local function attachVisual(player: Player, weaponId: string): boolean
	local hand = getHand(player.Character)
	local look = VISUALS[weaponId]
	if not hand or not look then
		return false
	end

	local part = Instance.new("Part")
	part.Name = VISUAL_NAME
	part.Size = look.size
	part.Color = look.color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true

	local grip = hand:FindFirstChild("RightGripAttachment")
	local gripOffset = grip and grip.CFrame or CFrame.new(0, -0.5, 0)
	local weld = Instance.new("Weld")
	weld.Part0 = hand
	weld.Part1 = part
	weld.C0 = gripOffset * CFrame.new(0, 0, -look.size.Z / 2)
	weld.Parent = part

	part.Parent = player.Character
	return true
end

-- API pública -------------------------------------------------------------

-- Devuelve el id del arma equipada (por ejemplo "Bat") o nil.
function CombatService:GetEquipped(player: Player): string?
	return equipped[player]
end

function CombatService:Unequip(player: Player)
	if equipped[player] == nil then
		return
	end
	equipped[player] = nil
	player:SetAttribute(ATTRIBUTE_NAME, nil)
	removeVisual(player)
end

-- Equipa un arma del inventario. Devuelve false si no se pudo.
function CombatService:Equip(player: Player, itemId): boolean
	local config = typeof(itemId) == "string" and Items[itemId]
	if not config or config.kind ~= "Weapon" or not Weapons[config.weaponId] then
		return false
	end
	if getInventory():Count(player, itemId) < 1 then
		return false
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	removeVisual(player)
	if not attachVisual(player, config.weaponId) then
		equipped[player] = nil
		player:SetAttribute(ATTRIBUTE_NAME, nil)
		return false
	end
	equipped[player] = itemId
	player:SetAttribute(ATTRIBUTE_NAME, itemId)
	return true
end

-- Si el arma equipada ya no está en el inventario (soltada, pasada o rota), se desequipa.
function CombatService:SyncWithInventory(player: Player)
	local itemId = equipped[player]
	if itemId and getInventory():Count(player, itemId) < 1 then
		CombatService:Unequip(player)
	end
end

-- Cuerpo a cuerpo ---------------------------------------------------------

-- ¿Está el objetivo dentro del cono frente al jugador? direction debe ser horizontal y unitaria.
function CombatService.inMeleeCone(origin: Vector3, direction: Vector3, targetPosition: Vector3, range: number): boolean
	local offset = Vector3.new(targetPosition.X - origin.X, 0, targetPosition.Z - origin.Z)
	local distance = offset.Magnitude
	if distance > range then
		return false
	end
	if distance < 0.001 then
		return true
	end
	return offset.Unit:Dot(direction) >= COS_MELEE_HALF_ANGLE
end

-- Normaliza la dirección que manda el cliente. Devuelve nil si no sirve.
local function sanitizeDirection(direction): Vector3?
	if typeof(direction) ~= "Vector3" then
		return nil
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	local magnitude = flat.Magnitude
	-- NaN e infinito no pasan la comparación; una mirada casi vertical tampoco.
	if not (magnitude > 0.01 and magnitude < math.huge) then
		return nil
	end
	return flat / magnitude
end

-- El equipo de infectados es de Rafael. Se puede cambiar el proveedor para pruebas.
local zombieProvider = nil
function CombatService:SetZombieProvider(provider)
	zombieProvider = provider
end

local function getZombies()
	return zombieProvider or require(script.Parent.ZombieService)
end

-- Infectados dentro del cono (sin repetir). Devuelve una lista de modelos.
local function findMeleeTargets(character: Model, origin: Vector3, direction: Vector3, range: number)
	local Zombies = getZombies()
	if type(Zombies.FromInstance) ~= "function" then
		return {}
	end

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	local found, targets = {}, {}
	for _, part in workspace:GetPartBoundsInRadius(origin, range, params) do
		local model = Zombies:FromInstance(part)
		if model and not found[model] then
			found[model] = true
			if CombatService.inMeleeCone(origin, direction, model:GetPivot().Position, range) then
				table.insert(targets, model)
			end
		end
	end
	return targets
end

local lastAttack = {} -- [Player] = os.clock() del último golpe

-- Un golpe cuerpo a cuerpo. Devuelve true y cuántos infectados golpeó,
-- o false y el motivo del rechazo. El servidor decide todo.
function CombatService:Attack(player: Player, direction)
	local look = sanitizeDirection(direction)
	if not look then
		return false, "invalidDirection"
	end

	local itemId = equipped[player]
	local weapon = itemId and Weapons[Items[itemId].weaponId]
	if not weapon then
		return false, "noWeapon"
	end
	if weapon.kind ~= "Melee" then
		return false, "notMelee"
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return false, "dead"
	end
	local Survival = require(script.Parent.SurvivalService)
	if type(Survival.IsDowned) == "function" and Survival:IsDowned(player) then
		return false, "downed"
	end

	local now = os.clock()
	if lastAttack[player] and now - lastAttack[player] < weapon.cooldown then
		return false, "cooldown"
	end
	lastAttack[player] = now

	local origin = root.Position
	local hits = 0
	for _, model in findMeleeTargets(character, origin, look, weapon.range) do
		getZombies():Damage(model, weapon.damage, player)
		hits += 1
	end

	-- Cada golpe hace ruido, acierte o no.
	require(script.Parent.NoiseService):Emit(origin, weapon.noiseRadius, player)

	if weapon.durability then
		local broken = getInventory():WearWeapon(player, itemId, 1, weapon.durability)
		if broken then
			Remotes.get("Notify"):FireClient(player, `Se rompió: {Items[itemId].displayName}`)
		end
	end
	return true, hits
end

-- Ciclo de vida -----------------------------------------------------------

local function onPlayerAdded(player: Player)
	-- Un personaje nuevo nace con las manos vacías.
	player.CharacterAdded:Connect(function()
		equipped[player] = nil
		player:SetAttribute(ATTRIBUTE_NAME, nil)
	end)
end

function CombatService:Init() end

function CombatService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		equipped[player] = nil
		lastAttack[player] = nil
	end)

	-- El cliente solo pide. Todo se valida en Attack.
	Remotes.get("RequestAttack").OnServerEvent:Connect(function(player, direction)
		CombatService:Attack(player, direction)
	end)
end

return CombatService
