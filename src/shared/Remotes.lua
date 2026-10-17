--!strict
-- Definición central de RemoteEvents. El servidor los crea; el cliente los espera.
-- Regla: el cliente solo PIDE acciones. El servidor valida todo.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FOLDER_NAME = "Remotes"

local EVENT_NAMES = {
	-- Cliente -> Servidor
	"RequestJoinGroup",
	"RequestLeaveGroup",
	"RequestAttack",
	"RequestReload",
	"RequestUseItem",
	"RequestDropItem",
	"RequestGiveItem",
	"RequestCraft",
	"RequestRevive",
	-- Servidor -> Cliente
	"RunStateChanged",
	"InventoryChanged",
	"SurvivalChanged",
	"WaveStarted",
	"NoiseEmitted",
	"Notify",
}

local Remotes = {}

if RunService:IsServer() then
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for _, name in EVENT_NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
end

function Remotes.get(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
