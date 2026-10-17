--!nonstrict
-- Elección aleatoria con pesos. Recibe un Random para poder probarla con semilla fija.

local Weighted = {}

-- entries: lista de tablas con campo weight. Devuelve la entrada elegida.
function Weighted.pick(entries, rng: Random)
	local total = 0
	for _, entry in entries do
		total += entry.weight
	end
	assert(total > 0, "Weighted.pick: la suma de pesos debe ser mayor que 0")

	local roll = rng:NextNumber() * total
	local acc = 0
	for _, entry in entries do
		acc += entry.weight
		if roll < acc then
			return entry
		end
	end
	return entries[#entries]
end

return Weighted
