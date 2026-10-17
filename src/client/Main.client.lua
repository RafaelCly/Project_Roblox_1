--!nonstrict
-- Punto de entrada del cliente: carga los controladores y los inicia.

local controllersFolder = script.Parent:WaitForChild("Controllers")

local controllers = {}

for _, moduleScript in controllersFolder:GetChildren() do
	if moduleScript:IsA("ModuleScript") then
		local ok, result = pcall(require, moduleScript)
		if ok then
			controllers[moduleScript.Name] = result
		else
			warn(`[Client] No se pudo cargar {moduleScript.Name}: {result}`)
		end
	end
end

for name, controller in controllers do
	if type(controller.Start) == "function" then
		task.spawn(function()
			local ok, err = pcall(controller.Start, controller)
			if not ok then
				warn(`[Client] Start falló en {name}: {err}`)
			end
		end)
	end
end
