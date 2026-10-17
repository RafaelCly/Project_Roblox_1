--!nonstrict
-- Pruebas automáticas del cliente. Solo corren dentro de Roblox Studio.
-- Resultado en la ventana Output: busca "[TestCliente]".

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not RunService:IsStudio() then
	return
end

local passed, failed = 0, 0

local function check(name: string, condition: boolean)
	if condition then
		passed += 1
		print(`[TestCliente] PASS {name}`)
	else
		failed += 1
		warn(`[TestCliente] FAIL {name}`)
	end
end

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))
local folder = ReplicatedStorage:WaitForChild("Remotes", 10)
check("el cliente ve la carpeta Remotes", folder ~= nil)

if folder then
	for _, name in Remotes.Names do
		local remote = folder:WaitForChild(name, 5)
		check(`el cliente ve el remote {name}`, remote ~= nil and remote:IsA("RemoteEvent"))
	end
end

-- Los controladores del cliente deben haberse cargado sin errores.
local controllers = script.Parent:WaitForChild("Controllers")
for _, moduleScript in controllers:GetChildren() do
	if moduleScript:IsA("ModuleScript") then
		local ok = pcall(require, moduleScript)
		check(`controlador {moduleScript.Name} carga`, ok)
	end
end

print(`[TestCliente] RESULTADO: {passed} PASS, {failed} FAIL`)
