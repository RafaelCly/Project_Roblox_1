--!nonstrict
-- Demostración para desarrollo: entrega y equipa un arma sola al aparecer, y puede atacar
-- cada cierto tiempo. Se controla con shared/Config/Dev.lua (DEMO_WEAPON y DEMO_ATTACK_EVERY).
-- Con DEMO_WEAPON = nil (lo normal) este script no hace nada.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

local Dev = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Dev"))
if not Dev.DEMO_WEAPON then
	return
end

task.wait(4) -- que Main inicie los servicios
local services = script.Parent:WaitForChild("Services")
local Inventory = require(services.InventoryService)
local Combat = require(services.CombatService)

local function giveAndEquip(player: Player)
	local character = player.Character or player.CharacterAdded:Wait()
	character:WaitForChild("HumanoidRootPart")
	task.wait(2)
	for _, child in character:GetChildren() do
		if child:IsA("ForceField") then
			child:Destroy()
		end
	end

	local item = Dev.DEMO_WEAPON
	Inventory:AddItem(player, item, 1)
	if item == "Pistol" then
		Inventory:AddItem(player, "PistolAmmo", 30)
	end
	Combat:Equip(player, item)
	if item == "Pistol" then
		Combat:_setMagazine(player, item, 12)
	end
	print(`[DevDemo] {player.Name} lleva {item}`)

	if Dev.DEMO_ATTACK_EVERY then
		task.spawn(function()
			while player.Parent and character.Parent do
				task.wait(Dev.DEMO_ATTACK_EVERY)
				local root = character:FindFirstChild("HumanoidRootPart")
				if not root then
					break
				end
				local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
				if item == "Pistol" and (Combat:GetMagazine(player) or 0) == 0 then
					Combat:_setMagazine(player, item, 12)
				end
				Combat:Attack(player, look, root.Position)
			end
		end)
	end
end

for _, player in Players:GetPlayers() do
	task.spawn(giveAndEquip, player)
end
Players.PlayerAdded:Connect(function(player)
	task.spawn(giveAndEquip, player)
end)
