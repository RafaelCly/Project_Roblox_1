--!nonstrict
-- CombatService
-- Armas del jugador: equipar, golpear, disparar y recargar. Dueño: Axel.
-- Solo hay un arma equipada a la vez. El servidor decide todo; el cliente ve el
-- estado como atributos del jugador:
--   EquippedWeapon  id del arma equipada (nil si no hay)
--   Magazine        balas en el cargador del arma de fuego equipada
--   Reloading       true mientras recarga

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Items = require(Shared.Config.Items)
local Weapons = require(Shared.Config.Weapons)
local WeaponModels = require(script.Parent.Parent.Util.WeaponModels)

local CombatService = {}

local VISUAL_NAME = "EquippedWeaponVisual"
local ATTRIBUTE_NAME = "EquippedWeapon"
local MAGAZINE_ATTRIBUTE = "Magazine"
local RELOADING_ATTRIBUTE = "Reloading"
local MELEE_HALF_ANGLE = 60 -- grados a cada lado de la mirada
local COS_MELEE_HALF_ANGLE = math.cos(math.rad(MELEE_HALF_ANGLE))
local MAX_AIM_ORIGIN_DISTANCE = 20 -- la cámara en tercera persona queda cerca del jugador
local MAX_CORPSES_PER_SHOT = 4 -- cadáveres que un rayo puede atravesar antes de rendirse

-- Piezas simples sin arte final: un bloque largo por arma.
local VISUALS = {
	Knife = { size = Vector3.new(0.2, 0.2, 1.4), color = Color3.fromRGB(170, 175, 180) },
	Bat = { size = Vector3.new(0.45, 0.45, 3), color = Color3.fromRGB(139, 99, 60) },
	Pistol = { size = Vector3.new(0.3, 0.7, 0.9), color = Color3.fromRGB(45, 45, 50) },
}

local equipped = {} -- [Player] = itemId
local magazines = {} -- [Player] = { [itemId] = balas en el cargador }
local reloading = {} -- [Player] = ficha de la recarga en curso
local lastAttack = {} -- [Player] = os.clock() del último golpe o disparo

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

	-- Con modelo de varias piezas (Util/WeaponModels), este bloque pasa a ser un ancla
	-- invisible en la palma y las piezas visibles cuelgan de él.
	if WeaponModels.has(weaponId) then
		weld.C0 = gripOffset
		WeaponModels.decorate(weaponId, part)
	end

	part.Parent = player.Character
	return true
end

local function weaponOf(itemId: string?)
	local item = itemId and Items[itemId]
	return item and Weapons[item.weaponId] or nil
end

-- Munición del cargador del arma `itemId` (0 si nunca se cargó).
local function rounds(player: Player, itemId: string): number
	local own = magazines[player]
	return own and own[itemId] or 0
end

local function setRounds(player: Player, itemId: string, value: number)
	magazines[player] = magazines[player] or {}
	magazines[player][itemId] = value
	if equipped[player] == itemId then
		player:SetAttribute(MAGAZINE_ATTRIBUTE, value)
	end
end

local function cancelReload(player: Player)
	reloading[player] = nil
	player:SetAttribute(RELOADING_ATTRIBUTE, nil)
end

-- API pública -------------------------------------------------------------

-- Devuelve el id del arma equipada (por ejemplo "Bat") o nil.
function CombatService:GetEquipped(player: Player): string?
	return equipped[player]
end

-- Balas en el cargador del arma equipada, o nil si no es un arma de fuego.
function CombatService:GetMagazine(player: Player): number?
	local itemId = equipped[player]
	local weapon = weaponOf(itemId)
	if itemId and weapon and weapon.kind == "Firearm" then
		return rounds(player, itemId)
	end
	return nil
end

function CombatService:IsReloading(player: Player): boolean
	return reloading[player] ~= nil
end

-- Solo para pruebas: fija las balas de un cargador.
function CombatService:_setMagazine(player: Player, itemId: string, value: number)
	setRounds(player, itemId, value)
end

function CombatService:Unequip(player: Player)
	if equipped[player] == nil then
		return
	end
	cancelReload(player)
	equipped[player] = nil
	player:SetAttribute(ATTRIBUTE_NAME, nil)
	player:SetAttribute(MAGAZINE_ATTRIBUTE, nil)
	removeVisual(player)
end

-- Equipa un arma del inventario. Devuelve false si no se pudo.
function CombatService:Equip(player: Player, itemId): boolean
	local config = typeof(itemId) == "string" and Items[itemId]
	local weapon = config and weaponOf(itemId)
	if not config or config.kind ~= "Weapon" or not weapon then
		return false
	end
	if getInventory():Count(player, itemId) < 1 then
		return false
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	if require(script.Parent.SurvivalService):IsDowned(player) then
		return false
	end

	cancelReload(player)
	removeVisual(player)
	if not attachVisual(player, config.weaponId) then
		equipped[player] = nil
		player:SetAttribute(ATTRIBUTE_NAME, nil)
		player:SetAttribute(MAGAZINE_ATTRIBUTE, nil)
		return false
	end
	equipped[player] = itemId
	player:SetAttribute(ATTRIBUTE_NAME, itemId)
	player:SetAttribute(MAGAZINE_ATTRIBUTE, weapon.kind == "Firearm" and rounds(player, itemId) or nil)
	return true
end

-- Si el arma equipada ya no está en el inventario (soltada, pasada o rota), se desequipa.
function CombatService:SyncWithInventory(player: Player)
	local itemId = equipped[player]
	if itemId and getInventory():Count(player, itemId) < 1 then
		CombatService:Unequip(player)
	end
end

-- Comprobaciones comunes ----------------------------------------------------

-- Datos del jugador listos para atacar o recargar, o false y el motivo.
local function attackContext(player: Player)
	local itemId = equipped[player]
	local weapon = weaponOf(itemId)
	if not weapon then
		return false, "noWeapon"
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
	return { itemId = itemId, weapon = weapon, character = character, root = root }
end

-- Marca el golpe o disparo si ya pasó el cooldown. Devuelve false si todavía no.
local function consumeCooldown(player: Player, weapon): boolean
	local now = os.clock()
	if lastAttack[player] and now - lastAttack[player] < weapon.cooldown then
		return false
	end
	lastAttack[player] = now
	return true
end

-- El equipo de infectados es de Rafael. Se puede cambiar el proveedor para pruebas.
local zombieProvider = nil
function CombatService:SetZombieProvider(provider)
	zombieProvider = provider
end

local function getZombies()
	return zombieProvider or require(script.Parent.ZombieService)
end

local function emitNoise(position: Vector3, weapon, player: Player)
	require(script.Parent.NoiseService):Emit(position, weapon.noiseRadius, player)
	-- Cada ataque aceptado sube este contador. Todos los clientes lo ven (atributo
	-- replicado) y WeaponAnimator anima el brazo del jugador que atacó.
	player:SetAttribute("AttackSeq", (player:GetAttribute("AttackSeq") or 0) + 1)
end

local function isDeadZombie(Zombies, model): boolean
	return type(Zombies.IsDead) == "function" and Zombies:IsDead(model) == true
end

-- Un vector que mande el cliente debe ser un número finito y no casi cero.
local function finiteVector(value): boolean
	return typeof(value) == "Vector3" and value.Magnitude > 0.01 and value.Magnitude < math.huge
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

-- Normaliza la dirección horizontal que manda el cliente. Devuelve nil si no sirve.
local function flatDirection(direction): Vector3?
	if not finiteVector(direction) then
		return nil
	end
	local flat = Vector3.new(direction.X, 0, direction.Z)
	local magnitude = flat.Magnitude
	-- Una mirada casi vertical no da dirección horizontal.
	if not (magnitude > 0.01) then
		return nil
	end
	return flat / magnitude
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
		if model and not found[model] and not isDeadZombie(Zombies, model) then
			found[model] = true
			if CombatService.inMeleeCone(origin, direction, model:GetPivot().Position, range) then
				table.insert(targets, model)
			end
		end
	end
	return targets
end

local function melee(player: Player, context, direction)
	local look = flatDirection(direction)
	if not look then
		return false, "invalidDirection"
	end
	local weapon = context.weapon
	if not consumeCooldown(player, weapon) then
		return false, "cooldown"
	end

	local origin = context.root.Position
	local hits = 0
	for _, model in findMeleeTargets(context.character, origin, look, weapon.range) do
		getZombies():Damage(model, weapon.damage, player)
		hits += 1
	end

	-- Cada golpe hace ruido, acierte o no.
	emitNoise(origin, weapon, player)

	if weapon.durability then
		local broken = getInventory():WearWeapon(player, context.itemId, 1, weapon.durability)
		if broken then
			Remotes.get("Notify"):FireClient(player, `Se rompió: {Items[context.itemId].displayName}`)
		end
	end
	return true, hits
end

-- Armas de fuego ------------------------------------------------------------

local function shoot(player: Player, context, direction, origin)
	if not finiteVector(direction) then
		return false, "invalidDirection"
	end
	if
		typeof(origin) ~= "Vector3"
		or not (origin.Magnitude < math.huge)
		or (origin - context.root.Position).Magnitude > MAX_AIM_ORIGIN_DISTANCE
	then
		return false, "invalidOrigin"
	end

	local weapon, itemId = context.weapon, context.itemId
	if reloading[player] then
		return false, "reloading"
	end
	if rounds(player, itemId) <= 0 then
		return false, "empty"
	end
	if not consumeCooldown(player, weapon) then
		return false, "cooldown"
	end
	setRounds(player, itemId, rounds(player, itemId) - 1)

	-- El rayo lo lanza el servidor. El cliente solo mostró el disparo al instante.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	-- Los compañeros tampoco frenan las balas: no hay fuego amigo y no deben hacer de escudo.
	local ignore = { context.character }
	for _, other in Players:GetPlayers() do
		if other.Character and other.Character ~= context.character then
			table.insert(ignore, other.Character)
		end
	end
	local pickups = workspace:FindFirstChild("Pickups")
	if pickups then
		table.insert(ignore, pickups)
	end
	params.FilterDescendantsInstances = ignore

	-- Los cadáveres no frenan las balas: se ignoran y el rayo sigue.
	local hits = 0
	local Zombies = getZombies()
	if type(Zombies.FromInstance) == "function" then
		for _ = 1, MAX_CORPSES_PER_SHOT do
			local result = workspace:Raycast(origin, direction.Unit * weapon.range, params)
			local model = result and Zombies:FromInstance(result.Instance)
			if model and isDeadZombie(Zombies, model) then
				table.insert(ignore, model)
				params.FilterDescendantsInstances = ignore
			else
				if model then
					Zombies:Damage(model, weapon.damage, player)
					hits = 1
				end
				break
			end
		end
	end

	emitNoise(context.root.Position, weapon, player)
	return true, hits
end

-- Un golpe o un disparo. `direction` es hacia donde apunta el jugador; para las armas de
-- fuego `origin` es el punto de partida del rayo (la cámara). Devuelve true y cuántos
-- infectados alcanzó, o false y el motivo del rechazo. El servidor decide todo.
function CombatService:Attack(player: Player, direction, origin)
	local context, reason = attackContext(player)
	if not context then
		return false, reason
	end
	if context.weapon.kind == "Firearm" then
		return shoot(player, context, direction, origin)
	end
	return melee(player, context, direction)
end

-- Recarga el arma de fuego equipada con munición del inventario. Tarda `reloadTime`.
-- Devuelve true si empezó a recargar, o false y el motivo.
function CombatService:Reload(player: Player)
	local context, reason = attackContext(player)
	if not context then
		return false, reason
	end
	local weapon, itemId = context.weapon, context.itemId
	if weapon.kind ~= "Firearm" then
		return false, "notFirearm"
	end
	if reloading[player] then
		return false, "reloading"
	end
	if rounds(player, itemId) >= weapon.magazineSize then
		return false, "full"
	end
	local Inventory = getInventory()
	if Inventory:Count(player, weapon.ammoId) < 1 then
		return false, "noAmmo"
	end

	local token = {}
	reloading[player] = token
	player:SetAttribute(RELOADING_ATTRIBUTE, true)
	task.delay(weapon.reloadTime, function()
		-- Si se cambió de arma, murió o salió, la recarga ya se canceló.
		if reloading[player] ~= token or equipped[player] ~= itemId then
			return
		end
		cancelReload(player)
		local missing = weapon.magazineSize - rounds(player, itemId)
		local taken = math.min(missing, Inventory:Count(player, weapon.ammoId))
		if taken > 0 and Inventory:RemoveItem(player, weapon.ammoId, taken) then
			setRounds(player, itemId, rounds(player, itemId) + taken)
		end
	end)
	return true
end

-- Ciclo de vida -----------------------------------------------------------

local function onPlayerAdded(player: Player)
	-- Un personaje nuevo nace con las manos vacías y sin balas.
	player.CharacterAdded:Connect(function()
		cancelReload(player)
		equipped[player] = nil
		magazines[player] = nil
		player:SetAttribute(ATTRIBUTE_NAME, nil)
		player:SetAttribute(MAGAZINE_ATTRIBUTE, nil)
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
		magazines[player] = nil
		reloading[player] = nil
		lastAttack[player] = nil
	end)

	-- El cliente solo pide. Todo se valida en Attack y Reload.
	Remotes.get("RequestAttack").OnServerEvent:Connect(function(player, direction, origin)
		CombatService:Attack(player, direction, origin)
	end)
	Remotes.get("RequestReload").OnServerEvent:Connect(function(player)
		CombatService:Reload(player)
	end)
end

return CombatService
