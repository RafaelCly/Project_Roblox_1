--!nonstrict
-- Guardado de perfil del jugador (estadísticas y cosméticos).
-- Solo guarda progreso LIGERO: nunca ventajas de poder (ver docs/diseno-mvp.md, 5.10).
-- Nota: no hay bloqueo de sesión entre servidores todavía. Si dos servidores abren
-- el mismo perfil a la vez, gana el último en guardar. Mejorar antes del lanzamiento.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local DataService = {}

local STORE_NAME = "PlayerProfile_v1"
local AUTOSAVE_SECONDS = 120
local MAX_ATTEMPTS = 3

local store = DataStoreService:GetDataStore(STORE_NAME)
local profiles = {} -- [Player] = profile

local function defaultProfile()
	return {
		version = 1,
		stats = {
			runsPlayed = 0,
			runsWon = 0,
			zombiesKilled = 0,
			bestTimeSeconds = 0,
		},
		cosmetics = {
			owned = {},
			equipped = {},
		},
	}
end

-- Completa campos que falten sin borrar los que ya existen.
local function reconcile(target, template)
	for key, value in template do
		if target[key] == nil then
			target[key] = type(value) == "table" and table.clone(value) or value
		elseif type(value) == "table" and type(target[key]) == "table" then
			reconcile(target[key], value)
		end
	end
end

local function withRetries(fn)
	local lastError
	for attempt = 1, MAX_ATTEMPTS do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = result
		task.wait(attempt) -- espera creciente
	end
	return false, lastError
end

local function loadProfile(player: Player)
	local key = `u_{player.UserId}`
	local ok, data = withRetries(function()
		return store:GetAsync(key)
	end)

	if not ok then
		warn(`[DataService] No se pudo cargar a {player.Name}: {data}`)
		-- Perfil temporal marcado como no guardable, para no pisar datos reales.
		local profile = defaultProfile()
		profile._unsaveable = true
		profiles[player] = profile
		return
	end

	local profile = type(data) == "table" and data or defaultProfile()
	reconcile(profile, defaultProfile())
	profiles[player] = profile
end

local function saveProfile(player: Player)
	local profile = profiles[player]
	if not profile or profile._unsaveable then
		return
	end
	local key = `u_{player.UserId}`
	local ok, err = withRetries(function()
		store:UpdateAsync(key, function()
			return profile
		end)
	end)
	if not ok then
		warn(`[DataService] No se pudo guardar a {player.Name}: {err}`)
	end
end

-- API pública -------------------------------------------------------------

-- Devuelve el perfil (solo lectura recomendada). nil si aún no cargó.
function DataService:Get(player: Player)
	return profiles[player]
end

-- Espera hasta que el perfil esté cargado (o el jugador se vaya).
function DataService:WaitForProfile(player: Player)
	while player.Parent == Players and not profiles[player] do
		task.wait(0.1)
	end
	return profiles[player]
end

-- Modifica el perfil de forma controlada: DataService:Update(player, function(p) ... end)
function DataService:Update(player: Player, mutate)
	local profile = profiles[player]
	if profile then
		mutate(profile)
	end
end

-- Ciclo de vida -----------------------------------------------------------

function DataService:Start()
	Players.PlayerAdded:Connect(loadProfile)
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		saveProfile(player)
		profiles[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player in profiles do
				task.spawn(saveProfile, player)
			end
		end
	end)

	game:BindToClose(function()
		for player in profiles do
			task.spawn(saveProfile, player)
		end
		task.wait(3)
	end)
end

return DataService
