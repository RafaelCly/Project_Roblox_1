--!nonstrict
-- InventoryUi
-- Barra de ranuras abajo al centro. Clic izquierdo o teclas 1 a 8 = usar. Clic derecho = soltar.
-- A la izquierda, botones de fabricación. El servidor valida todo.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))
local Items = require(Shared:WaitForChild("Config"):WaitForChild("Items"))
local Recipes = require(Shared:WaitForChild("Config"):WaitForChild("Recipes"))
local RunConfig = require(Shared:WaitForChild("Config"):WaitForChild("Run"))

local InventoryUi = {}

local SLOT_SIZE = 64
local SLOT_GAP = 6

local NUMBER_KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
}

local function describeInputs(inputs): string
	local parts = {}
	for id, needed in inputs do
		table.insert(parts, `{needed} {Items[id].displayName}`)
	end
	table.sort(parts)
	return table.concat(parts, " + ")
end

function InventoryUi:Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local useRemote = Remotes.get("RequestUseItem")
	local dropRemote = Remotes.get("RequestDropItem")
	local craftRemote = Remotes.get("RequestCraft")

	local gui = Instance.new("ScreenGui")
	gui.Name = "InventoryUi"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local slotCount = RunConfig.INVENTORY_SLOTS
	local barWidth = slotCount * SLOT_SIZE + (slotCount - 1) * SLOT_GAP

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -16)
	bar.Size = UDim2.fromOffset(barWidth, SLOT_SIZE)
	bar.BackgroundTransparency = 1
	bar.Parent = gui

	local slotButtons = {}
	for i = 1, slotCount do
		local button = Instance.new("TextButton")
		button.Name = `Slot{i}`
		button.Position = UDim2.fromOffset((i - 1) * (SLOT_SIZE + SLOT_GAP), 0)
		button.Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE)
		button.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		button.BackgroundTransparency = 0.2
		button.BorderSizePixel = 0
		button.AutoButtonColor = true
		button.Font = Enum.Font.GothamMedium
		button.TextSize = 12
		button.TextColor3 = Color3.new(1, 1, 1)
		button.TextWrapped = true
		button.Text = ""
		button.Parent = bar

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = button

		local keyLabel = Instance.new("TextLabel")
		keyLabel.Size = UDim2.fromOffset(16, 16)
		keyLabel.Position = UDim2.fromOffset(4, 2)
		keyLabel.BackgroundTransparency = 1
		keyLabel.Font = Enum.Font.GothamBold
		keyLabel.TextSize = 11
		keyLabel.TextColor3 = Color3.fromRGB(170, 170, 170)
		keyLabel.Text = tostring(i)
		keyLabel.Parent = button

		button.MouseButton1Click:Connect(function()
			useRemote:FireServer(i)
		end)
		button.MouseButton2Click:Connect(function()
			dropRemote:FireServer(i)
		end)
		slotButtons[i] = button
	end

	-- Fabricación: un botón por receta.
	local craftPanel = Instance.new("Frame")
	craftPanel.Name = "Craft"
	craftPanel.AnchorPoint = Vector2.new(0, 1)
	craftPanel.Position = UDim2.new(0, 16, 1, -120)
	craftPanel.Size = UDim2.fromOffset(240, 0)
	craftPanel.AutomaticSize = Enum.AutomaticSize.Y
	craftPanel.BackgroundTransparency = 1
	craftPanel.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.Name
	layout.Parent = craftPanel

	for recipeId, recipe in Recipes do
		local button = Instance.new("TextButton")
		button.Name = recipeId
		button.Size = UDim2.new(1, 0, 0, 38)
		button.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
		button.BackgroundTransparency = 0.2
		button.BorderSizePixel = 0
		button.Font = Enum.Font.Gotham
		button.TextSize = 12
		button.TextColor3 = Color3.new(1, 1, 1)
		button.TextWrapped = true
		button.Text = `Fabricar {recipe.displayName}\n({describeInputs(recipe.inputs)})`
		button.Parent = craftPanel

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 6)
		corner.Parent = button

		button.MouseButton1Click:Connect(function()
			craftRemote:FireServer(recipeId)
		end)
	end

	Remotes.get("InventoryChanged").OnClientEvent:Connect(function(slots)
		for i = 1, slotCount do
			local stack = slots[i]
			local button = slotButtons[i]
			if stack and stack.id then
				local config = Items[stack.id]
				local name = config and config.displayName or stack.id
				button.Text = stack.count > 1 and `{name}\nx{stack.count}` or name
				button.BackgroundTransparency = 0.05
			else
				button.Text = ""
				button.BackgroundTransparency = 0.5
			end
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		for i, keyCode in NUMBER_KEYS do
			if input.KeyCode == keyCode and i <= slotCount then
				useRemote:FireServer(i)
				return
			end
		end
	end)
end

return InventoryUi
