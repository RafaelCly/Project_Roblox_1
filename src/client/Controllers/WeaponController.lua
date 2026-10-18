--!nonstrict
-- WeaponController
-- Clic izquierdo = golpear (cuerpo a cuerpo) o disparar (pistola). R = recargar.
-- El servidor valida y decide el daño; aquí solo se piden las acciones y se muestra
-- el movimiento o el disparo al instante.

local Debris = game:GetService("Debris")
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
local TRACER_SECONDS = 0.06
local TRACER_COLOR = Color3.fromRGB(255, 220, 120)

local player = Players.LocalPlayer
local lastAction = 0

-- Configuración del arma equipada, o nil.
local function equippedWeapon()
	local itemId = player:GetAttribute("EquippedWeapon")
	local item = itemId and Items[itemId]
	return item and Weapons[item.weaponId] or nil
end

-- Movimiento local del arma. No cambia nada en el servidor.
-- Desactivado: ahora el brazo entero se anima en WeaponAnimator (a partir de AttackSeq).
-- Girar además el bloque del arma aquí lo deformaría.
local USE_BLOCK_SWING = false
local function playSwing(character: Model)
	if not USE_BLOCK_SWING then
		return
	end
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

-- Línea corta que va del arma al punto de impacto. Solo la ve este jugador.
local function drawTracer(character: Model, from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	if length < 0.5 then
		return
	end
	local tracer = Instance.new("Part")
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanQuery = false
	tracer.CanTouch = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = TRACER_COLOR
	tracer.Size = Vector3.new(0.08, 0.08, length)
	tracer.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -length / 2)
	tracer.Parent = workspace
	Debris:AddItem(tracer, TRACER_SECONDS)
end

local function swing(character: Model, root: BasePart)
	local look = root.CFrame.LookVector
	Remotes.get("RequestAttack"):FireServer(Vector3.new(look.X, 0, look.Z))
	playSwing(character)
end

-- Dispara un rayo desde la cámara hacia el puntero. El servidor repite el rayo y decide.
local function fire(character: Model, weapon)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	-- El servidor rechaza el disparo si el cargador está vacío o se está recargando.
	-- Aquí solo se evita el disparo falso cuando ya se sabe que no saldrá.
	if (player:GetAttribute("Magazine") or 0) <= 0 or player:GetAttribute("Reloading") then
		return
	end

	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { character }
	local pickups = workspace:FindFirstChild("Pickups")
	if pickups then
		table.insert(ignore, pickups)
	end
	params.FilterDescendantsInstances = ignore

	local result = workspace:Raycast(ray.Origin, ray.Direction * weapon.range, params)
	local endPoint = result and result.Position or ray.Origin + ray.Direction * weapon.range

	Remotes.get("RequestAttack"):FireServer(ray.Direction, ray.Origin)

	-- La pistola tiene un Attachment "Muzzle" en la punta del cañón (Util/WeaponModels).
	local visual = character:FindFirstChild(VISUAL_NAME)
	local muzzleAttachment = visual and visual:FindFirstChild("Muzzle")
	local muzzle = muzzleAttachment and muzzleAttachment.WorldPosition or visual and visual.Position or character:GetPivot().Position
	drawTracer(character, muzzle, endPoint)
end

local function onPrimaryAction()
	local weapon = equippedWeapon()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not weapon or not root then
		return
	end

	-- El servidor también controla el cooldown; esto solo evita mandar peticiones de más.
	local now = os.clock()
	if now - lastAction < weapon.cooldown then
		return
	end
	lastAction = now

	if weapon.kind == "Firearm" then
		fire(character, weapon)
	else
		swing(character, root)
	end
end

function WeaponController:Start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			onPrimaryAction()
		elseif input.KeyCode == Enum.KeyCode.R then
			local weapon = equippedWeapon()
			if weapon and weapon.kind == "Firearm" then
				Remotes.get("RequestReload"):FireServer()
			end
		end
	end)
end

return WeaponController
