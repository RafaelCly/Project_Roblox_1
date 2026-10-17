--!nonstrict
-- MatchService
-- Máquina de estados de la partida (30 minutos). Dueño: Rafael.
-- Se llama MatchService para no chocar con el servicio nativo RunService de Roblox.

local MatchService = {}

MatchService.States = {
	Lobby = "Lobby",
	Looting = "Looting",
	Wave = "Wave",
	BunkerDefense = "BunkerDefense",
	Won = "Won",
	Lost = "Lost",
}

local state = MatchService.States.Lobby
local listeners = {}

function MatchService:GetState()
	return state
end

-- Cambia de estado y avisa a quien se haya suscrito.
function MatchService:SetState(newState)
	assert(MatchService.States[newState], `Estado inválido: {tostring(newState)}`)
	if newState == state then
		return
	end
	local old = state
	state = newState
	for _, callback in listeners do
		task.spawn(callback, newState, old)
	end
end

function MatchService:OnStateChanged(callback)
	table.insert(listeners, callback)
end

function MatchService:Init() end

function MatchService:Start()
	-- TODO: ciclo de la partida según Config/Run (saqueo, oleadas, búnker, fin).
end

return MatchService
