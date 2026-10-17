--!nonstrict
-- HudController
-- Barras de vida y hambre, y mensajes cortos del servidor (Notify).
-- Munición del arma de fuego equipada (cargador / reserva).
-- Pendiente: indicador de ruido (semana 3).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Items = require(Shared:WaitForChild("Config"):WaitForChild("Items"))
local Weapons = require(Shared:WaitForChild("Config"):WaitForChild("Weapons"))

local HudController = {}

local function makeBar(parent: Instance, label: string, color: Color3, yOffset: number)
	local holder = Instance.new("Frame")
	holder.Name = label
	holder.Size = UDim2.fromOffset(220, 22)
	holder.Position = UDim2.new(0, 16, 1, yOffset)
	holder.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	holder.BackgroundTransparency = 0.25
	holder.BorderSizePixel = 0
	holder.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = holder

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = holder

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(0, 6)
	fillCorner.Parent = fill

	local text = Instance.new("TextLabel")
	text.Name = "Text"
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamMedium
	text.TextSize = 13
	text.TextColor3 = Color3.new(1, 1, 1)
	text.Text = label
	text.Parent = holder

	return fill, text
end

function HudController:Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "Hud"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local healthFill, healthText = makeBar(gui, "Vida", Color3.fromRGB(200, 60, 60), -86)
	local hungerFill, hungerText = makeBar(gui, "Hambre", Color3.fromRGB(210, 150, 50), -58)

	local message = Instance.new("TextLabel")
	message.Name = "Message"
	message.AnchorPoint = Vector2.new(0.5, 0)
	message.Position = UDim2.new(0.5, 0, 0, 90)
	message.Size = UDim2.fromOffset(360, 30)
	message.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	message.BackgroundTransparency = 0.3
	message.BorderSizePixel = 0
	message.Font = Enum.Font.GothamMedium
	message.TextSize = 16
	message.TextColor3 = Color3.new(1, 1, 1)
	message.Text = ""
	message.TextTransparency = 1
	message.BackgroundTransparency = 1
	message.Parent = gui

	-- Munición: "cargador / reserva". Solo se ve con un arma de fuego equipada.
	local ammoLabel = Instance.new("TextLabel")
	ammoLabel.Name = "Ammo"
	ammoLabel.AnchorPoint = Vector2.new(1, 1)
	ammoLabel.Position = UDim2.new(1, -16, 1, -86)
	ammoLabel.Size = UDim2.fromOffset(180, 44)
	ammoLabel.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
	ammoLabel.BackgroundTransparency = 0.25
	ammoLabel.BorderSizePixel = 0
	ammoLabel.Font = Enum.Font.GothamBold
	ammoLabel.TextSize = 22
	ammoLabel.TextColor3 = Color3.new(1, 1, 1)
	ammoLabel.Visible = false
	ammoLabel.Parent = gui

	local ammoCorner = Instance.new("UICorner")
	ammoCorner.CornerRadius = UDim.new(0, 8)
	ammoCorner.Parent = ammoLabel

	local localPlayer = Players.LocalPlayer
	local lastSlots = {}

	local function refreshAmmo()
		local itemId = localPlayer:GetAttribute("EquippedWeapon")
		local item = itemId and Items[itemId]
		local weapon = item and Weapons[item.weaponId]
		if not weapon or weapon.kind ~= "Firearm" then
			ammoLabel.Visible = false
			return
		end
		ammoLabel.Visible = true

		local reserve = 0
		for _, stack in lastSlots do
			if stack.id == weapon.ammoId then
				reserve += stack.count
			end
		end
		if localPlayer:GetAttribute("Reloading") then
			ammoLabel.Text = "Recargando..."
			ammoLabel.TextColor3 = Color3.fromRGB(240, 200, 90)
			return
		end
		local magazine = localPlayer:GetAttribute("Magazine") or 0
		ammoLabel.Text = `{magazine} / {reserve}`
		-- Rojo si no se puede disparar: cargador vacío.
		ammoLabel.TextColor3 = magazine > 0 and Color3.new(1, 1, 1) or Color3.fromRGB(220, 80, 80)
	end

	for _, attribute in { "EquippedWeapon", "Magazine", "Reloading" } do
		localPlayer:GetAttributeChangedSignal(attribute):Connect(refreshAmmo)
	end

	Remotes.get("InventoryChanged").OnClientEvent:Connect(function(slots)
		lastSlots = slots
		refreshAmmo()
	end)

	-- Caído: aviso grande con la cuenta regresiva para que un compañero te levante.
	local downedLabel = Instance.new("TextLabel")
	downedLabel.Name = "Downed"
	downedLabel.AnchorPoint = Vector2.new(0.5, 0)
	downedLabel.Position = UDim2.new(0.5, 0, 0, 140)
	downedLabel.Size = UDim2.fromOffset(420, 64)
	downedLabel.BackgroundColor3 = Color3.fromRGB(60, 10, 10)
	downedLabel.BackgroundTransparency = 0.2
	downedLabel.BorderSizePixel = 0
	downedLabel.Font = Enum.Font.GothamBold
	downedLabel.TextSize = 22
	downedLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
	downedLabel.Visible = false
	downedLabel.Parent = gui

	local downedCorner = Instance.new("UICorner")
	downedCorner.CornerRadius = UDim.new(0, 8)
	downedCorner.Parent = downedLabel

	local function refreshDowned()
		local isDowned = localPlayer:GetAttribute("Downed") == true
		downedLabel.Visible = isDowned
		if not isDowned then
			return
		end
		task.spawn(function()
			-- Mientras siga caído, actualiza el tiempo que queda.
			while localPlayer:GetAttribute("Downed") == true do
				local endsAt = localPlayer:GetAttribute("DownedEndsAt") or 0
				local seconds = math.max(0, math.ceil(endsAt - workspace:GetServerTimeNow()))
				downedLabel.Text = `Estás caído, espera ayuda\n{seconds} s`
				task.wait(0.2)
			end
		end)
	end
	localPlayer:GetAttributeChangedSignal("Downed"):Connect(refreshDowned)
	refreshDowned()

	local messageId = 0

	Remotes.get("SurvivalChanged").OnClientEvent:Connect(function(health, maxHealth, hunger, maxHunger)
		local healthRatio = math.clamp(health / maxHealth, 0, 1)
		local hungerRatio = math.clamp(hunger / maxHunger, 0, 1)
		healthFill.Size = UDim2.fromScale(healthRatio, 1)
		hungerFill.Size = UDim2.fromScale(hungerRatio, 1)
		healthText.Text = `Vida {math.ceil(health)}`
		hungerText.Text = `Hambre {math.ceil(hunger)}`
	end)

	Remotes.get("Notify").OnClientEvent:Connect(function(text)
		messageId += 1
		local current = messageId
		message.Text = tostring(text)
		message.TextTransparency = 0
		message.BackgroundTransparency = 0.3
		task.delay(2.5, function()
			if current == messageId then
				TweenService:Create(message, TweenInfo.new(0.4), { TextTransparency = 1, BackgroundTransparency = 1 }):Play()
			end
		end)
	end)
end

return HudController
