--!nonstrict
-- WeaponController
-- Clic izquierdo con un arma cuerpo a cuerpo equipada = golpear. El servidor valida y
-- decide el daño; aquí solo se pide el golpe y se muestra el movimiento al instante.
-- Pendiente (semana 2): pistola, recarga y efectos de disparo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Items = require(Shared:WaitForChild("Config"):WaitForChild("Items"))
local Weapons = require(Shared:WaitForChild("Config"):WaitForChild("Weapons"))

local WeaponController = {}

local VISUAL_NAME = "EquippedWeaponVisual"
local SWING_ANGLE = math.rad(-75)
local SWING_OUT = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SWING_BACK = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

local player = Players.LocalPlayer
local lastSwing = 0

-- Arma cuerpo a cuerpo equipada, o nil.
local function equippedMelee()
	local itemId = player:GetAttribute("EquippedWeapon")
	local item = itemId and Items[itemId]
	local weapon = item and Weapons[item.weaponId]
	if weapon and weapon.kind == "Melee" then
		return weapon
	end
	return nil
end

-- Movimiento local del arma. No cambia nada en el servidor.
local function playSwing(character: Model)
	local visual = character:FindFirstChild(VISUAL_NAME)
	local weld = visual and visual:FindFirstChildOfClass("Weld")
	if not weld then
		return
	end
	local rest = weld.C0
	local out = TweenService:Create(weld, SWING_OUT, { C0 = rest * CFrame.Angles(SWING_ANGLE, 0, 0) })
	out.Completed:Once(function()
		TweenService:Create(weld, SWING_BACK, { C0 = rest }):Play()
	end)
	out:Play()
end

local function attack()
	local weapon = equippedMelee()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not weapon or not root then
		return
	end

	-- El servidor también controla el cooldown; esto solo evita mandar peticiones de más.
	local now = os.clock()
	if now - lastSwing < weapon.cooldown then
		return
	end
	lastSwing = now

	local look = root.CFrame.LookVector
	Remotes.get("RequestAttack"):FireServer(Vector3.new(look.X, 0, look.Z))
	playSwing(character)
end

function WeaponController:Start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			attack()
		end
	end)
end

return WeaponController
