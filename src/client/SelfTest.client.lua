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

-- Animación de armas: sigue lo que hace la suite del servidor (equipa, ataca, desequipa) ------
-- Esperas largas a propósito: depende de cuándo llegue la suite del servidor a las armas.
local Dev = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Dev"))
if Dev.RUN_SELF_TESTS then
	task.spawn(function()
		local Players = game:GetService("Players")
		local localPlayer = Players.LocalPlayer
		local WeaponAnimator = require(controllers:WaitForChild("WeaponAnimator"))
		local animPassed, animFailed = 0, 0
		local function checkAnim(name: string, condition: boolean)
			if condition then
				animPassed += 1
				print(`[TestCliente] PASS animación: {name}`)
			else
				animFailed += 1
				warn(`[TestCliente] FAIL animación: {name}`)
			end
		end
		local deadline = os.clock() + 300
		local function waitFor(predicate): boolean
			while os.clock() < deadline do
				if predicate() then
					return true
				end
				task.wait(0.1)
			end
			return false
		end

		if not waitFor(function()
			return localPlayer:GetAttribute("EquippedWeapon") == "Bat"
		end) then
			checkAnim("el servidor equipó un bate a tiempo", false)
		else
			task.wait(0.6) -- que el animador cree y arranque la pista
			local pose = WeaponAnimator:GetPose(localPlayer)
			checkAnim("con el bate equipado la postura es la de listo (55°, 75°)", pose ~= nil and pose.s == 55 and pose.e == 75)
			checkAnim("con el bate equipado hay una pista reproduciéndose", WeaponAnimator:CountPlaying(localPlayer) >= 1)

			local seq0 = localPlayer:GetAttribute("AttackSeq") or 0
			if waitFor(function()
				return (localPlayer:GetAttribute("AttackSeq") or 0) ~= seq0
			end) then
				task.wait(0.05)
				checkAnim("al atacar se suma la pista de ataque a la postura", WeaponAnimator:CountPlaying(localPlayer) >= 2)
			else
				checkAnim("el servidor atacó a tiempo", false)
			end

			if waitFor(function()
				return localPlayer:GetAttribute("EquippedWeapon") == nil
			end) then
				task.wait(0.6)
				local rest = WeaponAnimator:GetPose(localPlayer)
				checkAnim("sin arma la postura vuelve a brazo libre", rest ~= nil and rest.s == 0 and rest.e == 0)
				checkAnim("sin arma no queda ninguna pista reproduciéndose", WeaponAnimator:CountPlaying(localPlayer) == 0)
			else
				checkAnim("el servidor desequipó el arma a tiempo", false)
			end
		end
		print(`[TestCliente] RESULTADO ANIMACION: {animPassed} PASS, {animFailed} FAIL`)
	end)
end
