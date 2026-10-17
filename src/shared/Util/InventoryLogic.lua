--!nonstrict
-- Lógica pura del inventario (sin jugadores ni Instances), fácil de probar.
-- Un inventario es { slotCount = n, slots = { [indice] = { id = "X", count = n } } }.
-- Una ranura vacía es nil.

local Items = require(script.Parent.Parent.Config.Items)

local InventoryLogic = {}

function InventoryLogic.new(slotCount: number)
	return { slotCount = slotCount, slots = {} }
end

function InventoryLogic.count(inv, id: string): number
	local total = 0
	for i = 1, inv.slotCount do
		local slot = inv.slots[i]
		if slot and slot.id == id then
			total += slot.count
		end
	end
	return total
end

-- Agrega objetos: primero rellena pilas existentes y luego usa ranuras vacías.
-- Devuelve el SOBRANTE (0 si todo entró).
function InventoryLogic.add(inv, id: string, count: number): number
	local config = Items[id]
	assert(config, `Objeto desconocido: {id}`)

	local remaining = count
	for i = 1, inv.slotCount do
		local slot = inv.slots[i]
		if slot and slot.id == id and slot.count < config.stackMax then
			local moved = math.min(config.stackMax - slot.count, remaining)
			slot.count += moved
			remaining -= moved
			if remaining == 0 then
				return 0
			end
		end
	end

	for i = 1, inv.slotCount do
		if not inv.slots[i] then
			local moved = math.min(config.stackMax, remaining)
			inv.slots[i] = { id = id, count = moved }
			remaining -= moved
			if remaining == 0 then
				return 0
			end
		end
	end

	return remaining
end

-- Quita objetos empezando por la última ranura. Si no hay suficientes, no cambia nada.
function InventoryLogic.remove(inv, id: string, count: number): boolean
	if InventoryLogic.count(inv, id) < count then
		return false
	end

	local remaining = count
	for i = inv.slotCount, 1, -1 do
		local slot = inv.slots[i]
		if slot and slot.id == id then
			local taken = math.min(slot.count, remaining)
			slot.count -= taken
			remaining -= taken
			if slot.count == 0 then
				inv.slots[i] = nil
			end
			if remaining == 0 then
				return true
			end
		end
	end
	return true
end

-- Quita de una ranura concreta (toda la pila si no se indica cantidad).
-- Devuelve el id y la cantidad quitada, o nil y 0 si la ranura estaba vacía.
function InventoryLogic.removeAt(inv, index: number, count: number?)
	local slot = inv.slots[index]
	if not slot then
		return nil, 0
	end
	local id = slot.id
	local taken = math.min(count or slot.count, slot.count)
	slot.count -= taken
	if slot.count == 0 then
		inv.slots[index] = nil
	end
	return id, taken
end

function InventoryLogic.canCraft(inv, recipe): boolean
	for id, needed in recipe.inputs do
		if InventoryLogic.count(inv, id) < needed then
			return false
		end
	end
	return true
end

-- Lista de largo fijo para enviar al cliente. Una ranura vacía es una tabla vacía.
function InventoryLogic.serialize(inv)
	local list = {}
	for i = 1, inv.slotCount do
		local slot = inv.slots[i]
		list[i] = slot and { id = slot.id, count = slot.count } or {}
	end
	return list
end

return InventoryLogic
