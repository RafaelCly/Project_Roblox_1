--!nonstrict
-- Pruebas automáticas del servidor. Solo corren dentro de Roblox Studio.
-- Resultado en la ventana Output: busca "[Test]". Cada línea es PASS o FAIL.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

if not RunService:IsStudio() then
	return
end

task.wait(2) -- deja que Main termine de iniciar los servicios

local passed, failed = 0, 0

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		print(`[Test] PASS {name}`)
	else
		failed += 1
		warn(`[Test] FAIL {name}{detail and (" - " .. detail) or ""}`)
	end
end

local function section(name: string)
	print(`[Test] ---- {name}`)
end

local Shared = ReplicatedStorage:WaitForChild("Shared")
local servicesFolder = script.Parent:WaitForChild("Services")

-- Remotes -------------------------------------------------------------------
section("Remotes")
local Remotes = require(Shared:WaitForChild("Remotes"))
local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
check("carpeta Remotes existe", remotesFolder ~= nil)
if remotesFolder then
	for _, name in Remotes.Names do
		local remote = remotesFolder:FindFirstChild(name)
		check(`remote {name}`, remote ~= nil and remote:IsA("RemoteEvent"))
	end
end

-- Config --------------------------------------------------------------------
section("Config")
local Weapons = require(Shared.Config.Weapons)
for id, weapon in Weapons do
	check(`arma {id}: valores válidos`, weapon.damage > 0 and weapon.range > 0 and weapon.cooldown > 0 and weapon.noiseRadius >= 0)
	if weapon.kind == "Firearm" then
		check(`arma {id}: tiene cargador y recarga`, weapon.magazineSize ~= nil and weapon.reloadTime ~= nil)
	end
end
check("el cuchillo es más silencioso que el bate", Weapons.Knife.noiseRadius < Weapons.Bat.noiseRadius)
check("el bate es más silencioso que la pistola", Weapons.Bat.noiseRadius < Weapons.Pistol.noiseRadius)

local Zombies = require(Shared.Config.Zombies)
for id, zombie in Zombies do
	check(`infectado {id}: valores válidos`, zombie.health > 0 and zombie.chaseSpeed >= zombie.walkSpeed and zombie.sightAngle > 0 and zombie.budgetCost > 0)
end

local RunConfig = require(Shared.Config.Run)
check("grupo: mínimo <= máximo", RunConfig.MIN_PLAYERS_TO_START <= RunConfig.MAX_PLAYERS)
check("grupo: máximo es 4", RunConfig.MAX_PLAYERS == 4)
check("grupo: se puede empezar con 2", RunConfig.MIN_PLAYERS_TO_START == 2)
check("revivir: 1 vez por jugador", RunConfig.REVIVES_PER_PLAYER == 1)
check("partida: máximo 30 minutos", RunConfig.RUN_DURATION_SECONDS <= 30 * 60)
local wavesOk = #RunConfig.Waves == 3
local previousStart = -1
local previousBudget = -1
for _, wave in RunConfig.Waves do
	if wave.startsAt <= previousStart or wave.budget <= previousBudget or wave.startsAt >= RunConfig.RUN_DURATION_SECONDS then
		wavesOk = false
	end
	previousStart, previousBudget = wave.startsAt, wave.budget
end
check("3 oleadas en orden creciente y dentro de la partida", wavesOk)

-- Servicios -----------------------------------------------------------------
section("Servicios")
local loaded = {}
for _, moduleScript in servicesFolder:GetChildren() do
	if moduleScript:IsA("ModuleScript") then
		local ok, result = pcall(require, moduleScript)
		check(`servicio {moduleScript.Name} carga`, ok and type(result) == "table", not ok and tostring(result) or nil)
		if ok then
			loaded[moduleScript.Name] = result
		end
	end
end
check("hay 14 servicios", next(loaded) ~= nil and #servicesFolder:GetChildren() == 14, `{#servicesFolder:GetChildren()}`)

-- MatchService --------------------------------------------------------------
section("MatchService")
local Match = loaded.MatchService
if Match then
	check("estado inicial es Lobby", Match:GetState() == "Lobby")
	local seen = {}
	Match:OnStateChanged(function(new, old)
		table.insert(seen, `{old}->{new}`)
	end)
	Match:SetState("Looting")
	Match:SetState("Looting") -- repetido: no debe avisar dos veces
	Match:SetState("Wave")
	task.wait()
	check("cambia de estado", Match:GetState() == "Wave")
	check("avisa cada cambio una sola vez", #seen == 2 and seen[1] == "Lobby->Looting" and seen[2] == "Looting->Wave", table.concat(seen, ","))
	check("rechaza un estado inválido", not pcall(Match.SetState, Match, "Inventado"))
	Match:SetState("Lobby") -- dejar como estaba
end

-- NoiseService --------------------------------------------------------------
section("NoiseService")
local Noise = loaded.NoiseService
if Noise then
	local got
	Noise:Subscribe(function(position, radius, source)
		got = { position = position, radius = radius, source = source }
	end)
	Noise:Emit(Vector3.new(1, 2, 3), Weapons.Pistol.noiseRadius, nil)
	task.wait()
	check("entrega el ruido al suscriptor", got ~= nil and got.position == Vector3.new(1, 2, 3) and got.radius == 120)
end

-- DataService ---------------------------------------------------------------
section("DataService")
local Data = loaded.DataService
if Data then
	local player = Players:GetPlayers()[1]
	if not player then
		player = Players.PlayerAdded:Wait()
	end
	local profile = Data:WaitForProfile(player)
	check("el jugador recibe un perfil", profile ~= nil)
	if profile then
		check("perfil: estadísticas por defecto", profile.stats.runsPlayed == 0 and profile.stats.runsWon == 0 and profile.stats.zombiesKilled == 0)
		check("perfil: cosméticos por defecto", type(profile.cosmetics.owned) == "table" and type(profile.cosmetics.equipped) == "table")
		check("perfil: versión 1", profile.version == 1)
		Data:Update(player, function(p)
			p.stats.zombiesKilled += 5
		end)
		check("Update modifica el perfil", Data:Get(player).stats.zombiesKilled == 5)
		Data:Update(player, function(p)
			p.stats.zombiesKilled = 0
		end)
		print(`[Test] INFO perfil guardable: {profile._unsaveable ~= true} (false es normal en Studio sin publicar)`)
	end
end

-- Objetos, recetas y botín (datos) --------------------------------------------
section("Items, recetas y botín")
local Items = require(Shared.Config.Items)
local Recipes = require(Shared.Config.Recipes)
local Loot = require(Shared.Config.Loot)

local itemsOk = true
for id, item in Items do
	if item.stackMax < 1 or #item.displayName == 0 then
		itemsOk = false
	end
	if item.kind == "Weapon" and Weapons[item.weaponId] == nil then
		itemsOk = false
	end
	if item.kind == "Food" and not (item.hunger and item.hunger > 0) then
		itemsOk = false
	end
	if item.kind == "Heal" and not (item.heal and item.heal > 0) then
		itemsOk = false
	end
end
check("todos los objetos son válidos", itemsOk)

local recipesOk = true
for id, recipe in Recipes do
	if Items[recipe.output.id] == nil or recipe.output.count < 1 then
		recipesOk = false
	end
	for inputId, needed in recipe.inputs do
		if Items[inputId] == nil or needed < 1 then
			recipesOk = false
		end
	end
end
check("todas las recetas usan objetos que existen", recipesOk)

local lootOk = true
for tableName, lootTable in Loot do
	if lootTable.chance <= 0 or lootTable.chance > 1 then
		lootOk = false
	end
	for _, entry in lootTable.entries do
		if Items[entry.id] == nil or entry.weight <= 0 or entry.count[1] > entry.count[2] or entry.count[1] < 1 then
			lootOk = false
		end
	end
end
check("las tablas de botín son válidas", lootOk)

-- InventoryLogic (pura) --------------------------------------------------------
section("InventoryLogic")
local Inv = require(Shared.Util.InventoryLogic)
local inv = Inv.new(3)
check("agregar devuelve 0 de sobrante", Inv.add(inv, "Cloth", 4) == 0)
check("contar objetos", Inv.count(inv, "Cloth") == 4)
Inv.add(inv, "Cloth", 8)
check("apila hasta stackMax y usa otra ranura", inv.slots[1].count == 10 and inv.slots[2].count == 2)
check("un arma ocupa una ranura", Inv.add(inv, "Pistol", 1) == 0 and inv.slots[3].id == "Pistol")
check("inventario lleno devuelve el sobrante", Inv.add(inv, "Knife", 1) == 1)
check("quitar de más falla y no cambia nada", Inv.remove(inv, "Cloth", 99) == false and Inv.count(inv, "Cloth") == 12)
check("quitar la cantidad exacta", Inv.remove(inv, "Cloth", 11) == true and Inv.count(inv, "Cloth") == 1)
check("quita primero de la última pila y libera la ranura", inv.slots[2] == nil and inv.slots[1].count == 1)
local removedId, removedCount = Inv.removeAt(inv, 3, 1)
check("removeAt devuelve lo quitado", removedId == "Pistol" and removedCount == 1 and inv.slots[3] == nil)
local emptyId, emptyCount = Inv.removeAt(inv, 3)
check("removeAt de una ranura vacía", emptyId == nil and emptyCount == 0)
check("no se puede fabricar sin materiales", Inv.canCraft(inv, Recipes.Bandage) == false)
Inv.add(inv, "Cloth", 1)
check("se puede fabricar con materiales", Inv.canCraft(inv, Recipes.Bandage) == true)
local serialized = Inv.serialize(inv)
check("serializar da una lista de largo fijo", #serialized == 3 and serialized[1].id == "Cloth" and next(serialized[2]) == nil)
check("objeto desconocido falla", not pcall(Inv.add, inv, "Inventado", 1))

-- Supervivencia (pura) ---------------------------------------------------------
section("Supervivencia (pura)")
local Survival = loaded.SurvivalService
local SurvivalConfig = require(Shared.Config.Survival)
if Survival then
	local after, starving = Survival.stepHunger(100, 10)
	check("el hambre baja con el tiempo", math.abs(after - (100 - SurvivalConfig.HUNGER_DECAY_PER_SECOND * 10)) < 1e-6 and starving == false)
	local floor, starvingAtZero = Survival.stepHunger(0.1, 10)
	check("el hambre no baja de 0 y avisa de inanición", floor == 0 and starvingAtZero == true)
end

-- Botín (dados) ----------------------------------------------------------------
section("Botín (dados)")
local LootService = loaded.LootService
if LootService then
	local random = Random.new(42)
	local seen = {}
	local empty, valid = 0, true
	for _ = 1, 3000 do
		local id, count = LootService.rollEntry("House", random)
		if id == nil then
			empty += 1
		else
			seen[id] = (seen[id] or 0) + 1
			if Items[id] == nil or count < 1 then
				valid = false
			end
		end
	end
	check("todas las tiradas dan objetos válidos", valid)
	check("algunos puntos salen vacíos (~25%)", empty > 3000 * 0.18 and empty < 3000 * 0.32, tostring(empty))
	check("la comida es más común que la pistola", (seen.CannedFood or 0) > (seen.Pistol or 0) * 4)
	check("una tabla inexistente no da nada", LootService.rollEntry("NoExiste", random) == nil)
end

-- Integración con el jugador real ------------------------------------------------
section("Inventario y supervivencia con el jugador")
local Inventory = loaded.InventoryService
local testPlayer = Players:GetPlayers()[1]
if Inventory and Survival and testPlayer then
	local character = testPlayer.Character or testPlayer.CharacterAdded:Wait()
	local humanoid = character:WaitForChild("Humanoid")
	task.wait(1.5)

	local function slotOf(id)
		local playerInv = Inventory:Get(testPlayer)
		for i = 1, playerInv.slotCount do
			if playerInv.slots[i] and playerInv.slots[i].id == id then
				return i
			end
		end
		return nil
	end

	local pickups = workspace:FindFirstChild("Pickups")
	check("existe la carpeta Pickups", pickups ~= nil)
	check("la casa de prueba generó botín", pickups ~= nil and #pickups:GetChildren() >= 1)
	check("el jugador empieza con 8 ranuras vacías", Inventory:Get(testPlayer) ~= nil and Inventory:Get(testPlayer).slotCount == 8)
	check("vida máxima 100", humanoid.MaxHealth == 100)
	check("hambre inicial 100", Survival:GetHunger(testPlayer) ~= nil and Survival:GetHunger(testPlayer) <= 100)

	-- Comida
	check("agregar comida", Inventory:AddItem(testPlayer, "CannedFood", 2) == 0)
	Survival:SetHunger(testPlayer, 10)
	check("usar comida sube el hambre", Inventory:UseSlot(testPlayer, slotOf("CannedFood")) == true and math.abs(Survival:GetHunger(testPlayer) - 45) < 1)
	check("la comida consume una unidad", Inventory:Count(testPlayer, "CannedFood") == 1)
	Survival:SetHunger(testPlayer, 100)
	check("no se come con el hambre llena", Inventory:UseSlot(testPlayer, slotOf("CannedFood")) == false and Inventory:Count(testPlayer, "CannedFood") == 1)
	Inventory:RemoveItem(testPlayer, "CannedFood", 1)

	-- Venda
	Inventory:AddItem(testPlayer, "Bandage", 1)
	humanoid.Health = 50
	check("usar una venda cura", Inventory:UseSlot(testPlayer, slotOf("Bandage")) == true and humanoid.Health >= 80)
	Inventory:AddItem(testPlayer, "Bandage", 1)
	humanoid.Health = humanoid.MaxHealth
	check("no se usa venda con la vida completa", Inventory:UseSlot(testPlayer, slotOf("Bandage")) == false and Inventory:Count(testPlayer, "Bandage") == 1)
	Inventory:RemoveItem(testPlayer, "Bandage", 1)

	-- Objetos que no se pueden "usar"
	Inventory:AddItem(testPlayer, "Cloth", 1)
	check("la tela no se puede usar", Inventory:UseSlot(testPlayer, slotOf("Cloth")) == false and Inventory:Count(testPlayer, "Cloth") == 1)
	Inventory:RemoveItem(testPlayer, "Cloth", 1)

	-- Entradas inválidas del cliente
	check("ranura inválida se rechaza", Inventory:UseSlot(testPlayer, 99) == false and Inventory:UseSlot(testPlayer, "uno") == false and Inventory:UseSlot(testPlayer, 1.5) == false)
	check("fabricar receta inexistente se rechaza", Inventory:Craft(testPlayer, "Inventada") == false and Inventory:Craft(testPlayer, 123) == false)
	check("pasar a un jugador inexistente se rechaza", Inventory:GiveSlot(testPlayer, 1, 999999999) == false)
	check("pasarse a sí mismo se rechaza", Inventory:GiveSlot(testPlayer, 1, testPlayer.UserId) == false)

	-- Fabricar
	check("fabricar sin materiales falla", Inventory:Craft(testPlayer, "Bandage") == false)
	Inventory:AddItem(testPlayer, "Cloth", 2)
	check("fabricar una venda", Inventory:Craft(testPlayer, "Bandage") == true and Inventory:Count(testPlayer, "Bandage") == 1 and Inventory:Count(testPlayer, "Cloth") == 0)
	Inventory:RemoveItem(testPlayer, "Bandage", 1)

	-- Fabricar con el inventario lleno no gasta materiales
	-- 7 pistolas + 3 telas llenan las 8 ranuras. La venda gasta 2 telas pero queda 1,
	-- así que ninguna ranura se libera y el resultado no cabe.
	for _ = 1, 7 do
		Inventory:AddItem(testPlayer, "Pistol", 1)
	end
	Inventory:AddItem(testPlayer, "Cloth", 3)
	check("fabricar sin espacio para el resultado no gasta materiales", Inventory:Craft(testPlayer, "Bandage") == false and Inventory:Count(testPlayer, "Cloth") == 3 and Inventory:Count(testPlayer, "Bandage") == 0)
	Inventory:RemoveItem(testPlayer, "Pistol", 7)
	Inventory:RemoveItem(testPlayer, "Cloth", 3)

	-- Soltar y recoger
	Inventory:AddItem(testPlayer, "Pistol", 1)
	local before = #pickups:GetChildren()
	check("soltar un objeto", Inventory:DropSlot(testPlayer, slotOf("Pistol")) == true and Inventory:Count(testPlayer, "Pistol") == 0)
	check("el objeto soltado aparece en el suelo", #pickups:GetChildren() == before + 1)
	local dropped
	for _, pickup in pickups:GetChildren() do
		if pickup:GetAttribute("ItemId") == "Pistol" then
			dropped = pickup
		end
	end
	check("el objeto soltado existe", dropped ~= nil)
	if dropped then
		check("recoger lo soltado", Inventory:_collect(testPlayer, dropped) == true and Inventory:Count(testPlayer, "Pistol") == 1)
		check("el objeto recogido desaparece del suelo", dropped.Parent == nil)
		check("no se recoge dos veces", Inventory:_collect(testPlayer, dropped) == false and Inventory:Count(testPlayer, "Pistol") == 1)
	end
	Inventory:RemoveItem(testPlayer, "Pistol", 1)

	-- Recoger con inventario parcialmente lleno: lo que no cabe se queda en el suelo
	for _ = 1, 7 do
		Inventory:AddItem(testPlayer, "Pistol", 1)
	end
	Inventory:AddItem(testPlayer, "PistolAmmo", 25)
	local ammoPickup = Inventory:SpawnPickup(character.HumanoidRootPart.Position, "PistolAmmo", 10)
	check("recoger con poco espacio toma lo que cabe", Inventory:_collect(testPlayer, ammoPickup) == true and Inventory:Count(testPlayer, "PistolAmmo") == 30)
	check("lo que no cabe se queda en el suelo", ammoPickup.Parent ~= nil and ammoPickup:GetAttribute("Count") == 5)
	ammoPickup:Destroy()
	Inventory:RemoveItem(testPlayer, "Pistol", 7)
	Inventory:RemoveItem(testPlayer, "PistolAmmo", 30)

	-- Equipar armas
	section("Equipar armas")
	local Combat = loaded.CombatService
	local function visualCount()
		local total = 0
		for _, child in character:GetChildren() do
			if child.Name == "EquippedWeaponVisual" then
				total += 1
			end
		end
		return total
	end
	check("sin arma al empezar", Combat:GetEquipped(testPlayer) == nil and visualCount() == 0)
	check("no se equipa un arma que no se tiene", Combat:Equip(testPlayer, "Bat") == false and Combat:GetEquipped(testPlayer) == nil)
	check("no se equipa un objeto que no es arma", Combat:Equip(testPlayer, "Cloth") == false and Combat:Equip(testPlayer, "Inventada") == false and Combat:Equip(testPlayer, 5) == false)

	Inventory:AddItem(testPlayer, "Bat", 1)
	Inventory:AddItem(testPlayer, "Knife", 1)
	check("usar una ranura de arma la equipa", Inventory:UseSlot(testPlayer, slotOf("Bat")) == true and Combat:GetEquipped(testPlayer) == "Bat")
	check("equipar no gasta el arma", Inventory:Count(testPlayer, "Bat") == 1)
	check("el arma equipada se ve en el personaje", visualCount() == 1)
	check("el arma equipada se replica como atributo", testPlayer:GetAttribute("EquippedWeapon") == "Bat")
	check("usar otra arma cambia la equipada y solo hay una", Inventory:UseSlot(testPlayer, slotOf("Knife")) == true and Combat:GetEquipped(testPlayer) == "Knife" and visualCount() == 1)
	check("usar el arma equipada la guarda", Inventory:UseSlot(testPlayer, slotOf("Knife")) == true and Combat:GetEquipped(testPlayer) == nil and visualCount() == 0)
	check("guardar el arma limpia el atributo", testPlayer:GetAttribute("EquippedWeapon") == nil)

	Combat:Equip(testPlayer, "Bat")
	check("soltar el arma equipada la desequipa", Inventory:DropSlot(testPlayer, slotOf("Bat")) == true and Combat:GetEquipped(testPlayer) == nil and visualCount() == 0)
	Combat:Equip(testPlayer, "Knife")
	Inventory:RemoveItem(testPlayer, "Knife", 1)
	check("si el arma sale del inventario se desequipa", Combat:GetEquipped(testPlayer) == nil and visualCount() == 0)
	for _, pickup in pickups:GetChildren() do
		if pickup:GetAttribute("ItemId") == "Bat" then
			pickup:Destroy()
		end
	end

	-- Morir suelta todo
	Inventory:AddItem(testPlayer, "CannedFood", 2)
	Inventory:AddItem(testPlayer, "Bat", 1)
	local pickupsBeforeDeath = #pickups:GetChildren()
	humanoid.Health = 0
	task.wait(1)
	check("al morir se suelta todo el inventario", Inventory:Count(testPlayer, "CannedFood") == 0 and Inventory:Count(testPlayer, "Bat") == 0)
	check("lo soltado al morir queda en el suelo para el equipo", #pickups:GetChildren() == pickupsBeforeDeath + 2)
else
	warn("[Test] FAIL no hay jugador para las pruebas de integración")
	failed += 1
end

print(`[Test] RESULTADO: {passed} PASS, {failed} FAIL`)
