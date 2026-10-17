--!nonstrict
-- CombatService
-- Armas del jugador: equipar y mostrar el arma en la mano. Dueño: Axel.
-- Solo hay un arma equipada a la vez. El servidor decide cuál está equipada;
-- el cliente la ve como atributo "EquippedWeapon" del jugador.
-- Pendiente (semana 2): cuerpo a cuerpo, pistola y munición.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Config.Items)
local Weapons = require(Shared.Config.Weapons)

local CombatService = {}

local VISUAL_NAME = "EquippedWeaponVisual"
local ATTRIBUTE_NAME = "EquippedWeapon"

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
	end)
end

return CombatService
