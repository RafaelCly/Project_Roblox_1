--!nonstrict
-- Parámetros del mapa modular (semana 3). Todas las medidas en studs.

local Map = {
	GRID_SIZE = 4, -- el mapa es una cuadrícula de GRID_SIZE x GRID_SIZE zonas
	ZONE_SIZE = 60, -- lado de cada zona
	STREET_WIDTH = 6, -- calle que rodea cada zona; entre dos zonas suma el doble
	-- Esquina del mapa en el mundo. Lejos de la casa de prueba (Dev/DevHouse en 40, 0, 0).
	ORIGIN = Vector3.new(500, 0, 500),

	-- Módulos que se reparten al azar. La zona de partida (Plaza) y la del búnker
	-- (Bunker) se colocan aparte, en bordes opuestos.
	MODULES = {
		{ id = "House", weight = 4, isBuilding = true },
		{ id = "GasStation", weight = 2, isBuilding = true },
		{ id = "Forest", weight = 3, isBuilding = false },
		{ id = "Plaza", weight = 2, isBuilding = false },
	},
	MIN_BUILDINGS = 6, -- al menos tantos edificios, para esconder las piezas del búnker

	PLAYER_SPAWNS = 6, -- puntos de aparición en la zona de partida
	SPAWN_HEIGHT = 3, -- altura sobre el suelo de los puntos de aparición
	-- Los infectados solo aparecen en zonas a esta distancia (en zonas, Chebyshev) o más
	-- de la zona de partida.
	ZOMBIE_MIN_ZONE_DISTANCE = 2,
	ZOMBIE_SPAWNS_PER_ZONE = 2,
}

return Map
