--!nonstrict
-- HudController
-- Barras de vida y hambre, y mensajes cortos del servidor (Notify).
-- Pendiente: munición e indicador de ruido (semana 2 y 3).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

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
