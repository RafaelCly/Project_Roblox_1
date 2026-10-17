--!nonstrict
-- NoiseService
-- Eventos de ruido: la pistola, el bate y correr atraen infectados. Compartido.

local NoiseService = {}

local listeners = {}

-- Emite ruido en una posición con un radio en studs. ZombieService se suscribe.
function NoiseService:Emit(position: Vector3, radius: number, source: Player?)
	for _, callback in listeners do
		task.spawn(callback, position, radius, source)
	end
end

function NoiseService:Subscribe(callback)
	table.insert(listeners, callback)
end

function NoiseService:Init() end

function NoiseService:Start() end

return NoiseService
