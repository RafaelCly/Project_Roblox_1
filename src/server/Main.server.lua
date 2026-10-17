--!nonstrict
-- Punto de entrada del servidor: carga cada servicio, llama Init() en todos
-- y luego Start() en todos. Así un servicio puede usar a otro en Start().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Crea los RemoteEvents antes de que cualquier cliente los pida.
require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local servicesFolder = script.Parent:WaitForChild("Services")

local services = {}

for _, moduleScript in servicesFolder:GetChildren() do
	if moduleScript:IsA("ModuleScript") then
		local ok, result = pcall(require, moduleScript)
		if ok then
			services[moduleScript.Name] = result
		else
			warn(`[Main] No se pudo cargar {moduleScript.Name}: {result}`)
		end
	end
end

for name, service in services do
	if type(service.Init) == "function" then
		local ok, err = pcall(service.Init, service)
		if not ok then
			warn(`[Main] Init falló en {name}: {err}`)
		end
	end
end

for name, service in services do
	if type(service.Start) == "function" then
		task.spawn(function()
			local ok, err = pcall(service.Start, service)
			if not ok then
				warn(`[Main] Start falló en {name}: {err}`)
			end
		end)
	end
end

print("[Last Refuge] Servidor iniciado con servicios:", #servicesFolder:GetChildren())
