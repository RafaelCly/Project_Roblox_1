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

-- ZombieService -------------------------------------------------------------------
section("ZombieService")
local ZombieSvc = loaded.ZombieService
if ZombieSvc then
	local zombiesFolder = workspace:FindFirstChild("Zombies")
	check("existe la carpeta Zombies", zombiesFolder ~= nil)
	check("empieza sin infectados vivos", ZombieSvc:CountActive() == 0)

	local walker = ZombieSvc:Spawn("Walker", Vector3.new(0, 0, 60))
	check("Spawn devuelve un modelo", walker ~= nil and walker:IsA("Model"))
	if walker then
		local walkerHumanoid = walker:FindFirstChildOfClass("Humanoid")
		check("el modelo está en workspace.Zombies", walker.Parent == zombiesFolder)
		check("el caminante tiene la vida y velocidad de su config", walkerHumanoid.MaxHealth == Zombies.Walker.health and walkerHumanoid.Health == Zombies.Walker.health and walkerHumanoid.WalkSpeed == Zombies.Walker.walkSpeed)
		check("el modelo guarda su tipo", walker:GetAttribute("ZombieType") == "Walker" and walker:GetAttribute("IsZombie") == true)
		check("el infectado se cuenta como vivo", ZombieSvc:CountActive() == 1)
		check("el servidor es dueño de la física", walker.HumanoidRootPart:GetNetworkOwner() == nil)
		check("el infectado no queda bajo el suelo", walker.HumanoidRootPart.Position.Y > -5)

		-- FromInstance
		check("FromInstance desde el modelo", ZombieSvc:FromInstance(walker) == walker)
		check("FromInstance desde una de sus partes", ZombieSvc:FromInstance(walker:FindFirstChild("Head")) == walker)
		check("FromInstance con algo que no es infectado", ZombieSvc:FromInstance(workspace.Terrain) == nil)
		check("FromInstance con nil", ZombieSvc:FromInstance(nil) == nil)

		-- Damage
		check("un golpe no letal devuelve false", ZombieSvc:Damage(walker, 30, testPlayer) == false)
		check("el golpe resta vida", walkerHumanoid.Health == Zombies.Walker.health - 30)
		check("recuerda quién lo golpeó", ZombieSvc:GetRecord(walker).lastAttacker == testPlayer)
		check("un daño inválido se ignora", ZombieSvc:Damage(walker, -5, testPlayer) == false and ZombieSvc:Damage(walker, "mucho", testPlayer) == false and walkerHumanoid.Health == Zombies.Walker.health - 30)
		check("un golpe letal devuelve true", ZombieSvc:Damage(walker, 999, testPlayer) == true)
		check("el infectado muerto ya no cuenta como vivo", ZombieSvc:CountActive() == 0 and ZombieSvc:IsDead(walker))
		check("no se puede matar dos veces", ZombieSvc:Damage(walker, 10, testPlayer) == false)
	end

	-- Otros tipos
	local runner = ZombieSvc:Spawn("Runner", Vector3.new(4, 0, 60))
	local brute = ZombieSvc:Spawn("Brute", Vector3.new(8, 0, 60))
	check("el corredor tiene su vida y velocidad", runner ~= nil and runner:FindFirstChildOfClass("Humanoid").MaxHealth == Zombies.Runner.health and runner:FindFirstChildOfClass("Humanoid").WalkSpeed == Zombies.Runner.walkSpeed)
	check("el bruto tiene su vida", brute ~= nil and brute:FindFirstChildOfClass("Humanoid").MaxHealth == Zombies.Brute.health)

	-- Tipo inválido
	check("un tipo inexistente falla", not pcall(ZombieSvc.Spawn, ZombieSvc, "Dragon", Vector3.zero))

	-- Límite de infectados activos
	local originalLimit = RunConfig.MAX_ACTIVE_ZOMBIES
	RunConfig.MAX_ACTIVE_ZOMBIES = ZombieSvc:CountActive() + 1
	local allowed = ZombieSvc:Spawn("Walker", Vector3.new(12, 0, 60))
	local blocked = ZombieSvc:Spawn("Walker", Vector3.new(16, 0, 60))
	check("respeta el límite de infectados activos", allowed ~= nil and blocked == nil)
	RunConfig.MAX_ACTIVE_ZOMBIES = originalLimit

	-- Comando de desarrollo
	local before = ZombieSvc:CountActive()
	workspace:SetAttribute("DevSpawnZombies", 3)
	task.wait(1)
	check("el comando de desarrollo crea 3 infectados", ZombieSvc:CountActive() == before + 3)
	check("el comando se reinicia solo", workspace:GetAttribute("DevSpawnZombies") == nil)

	-- Limpieza
	for _, child in zombiesFolder:GetChildren() do
		if ZombieSvc:GetRecord(child) then
			ZombieSvc:Damage(child, 99999, nil)
		end
	end
	check("tras limpiar no quedan infectados vivos", ZombieSvc:CountActive() == 0)
end

-- ZombieBrain (decisiones puras) --------------------------------------------------
section("ZombieBrain")
local Brain = require(Shared.Util.ZombieBrain)
local AI = require(Shared.Config.ZombieAI)
local function brainCtx(overrides)
	local context = {
		hasTarget = false,
		distance = 0,
		attackRange = 4.5,
		timeInState = 0,
		idleTime = 3,
		wanderTimeout = 8,
		investigateTimeout = 10,
		reachedPoint = false,
		targetLostFor = math.huge,
		loseSeconds = 2,
	}
	for key, value in overrides do
		context[key] = value
	end
	return context
end
check("Idle espera antes de deambular", Brain.next("Idle", brainCtx({ timeInState = 1 })) == "Idle")
check("Idle pasa a Wander al cumplir su espera", Brain.next("Idle", brainCtx({ timeInState = 3 })) == "Wander")
check("Idle ve un jugador lejos: persigue", Brain.next("Idle", brainCtx({ hasTarget = true, distance = 12 })) == "Chase")
check("Idle ve un jugador cerca: ataca", Brain.next("Idle", brainCtx({ hasTarget = true, distance = 3 })) == "Attack")
check("Wander sigue caminando", Brain.next("Wander", brainCtx({ timeInState = 2 })) == "Wander")
check("Wander llegó: vuelve a Idle", Brain.next("Wander", brainCtx({ reachedPoint = true })) == "Idle")
check("Wander se rinde por tiempo", Brain.next("Wander", brainCtx({ timeInState = 8 })) == "Idle")
check("Wander ve un jugador: persigue", Brain.next("Wander", brainCtx({ hasTarget = true, distance = 10 })) == "Chase")
check("Investigate sigue yendo al punto", Brain.next("Investigate", brainCtx({ timeInState = 3 })) == "Investigate")
check("Investigate llegó: vuelve a Idle", Brain.next("Investigate", brainCtx({ reachedPoint = true })) == "Idle")
check("Investigate se rinde por tiempo", Brain.next("Investigate", brainCtx({ timeInState = 10 })) == "Idle")
check("Investigate ve un jugador: persigue", Brain.next("Investigate", brainCtx({ hasTarget = true, distance = 9 })) == "Chase")
check("Chase sigue si el jugador está lejos", Brain.next("Chase", brainCtx({ hasTarget = true, distance = 10 })) == "Chase")
check("Chase pasa a Attack al llegar", Brain.next("Chase", brainCtx({ hasTarget = true, distance = 4 })) == "Attack")
check("Chase aguanta unos segundos sin ver al jugador", Brain.next("Chase", brainCtx({ targetLostFor = 1 })) == "Chase")
check("Chase pierde al jugador y va a Investigate", Brain.next("Chase", brainCtx({ targetLostFor = 2 })) == "Investigate")
check("Attack sigue atacando a corta distancia", Brain.next("Attack", brainCtx({ hasTarget = true, distance = 3 })) == "Attack")
check("Attack tiene margen en el borde del rango", Brain.next("Attack", brainCtx({ hasTarget = true, distance = 4.5 * 1.2 })) == "Attack")
check("Attack vuelve a Chase si el jugador se aleja", Brain.next("Attack", brainCtx({ hasTarget = true, distance = 4.5 * 1.4 })) == "Chase")
check("Attack sin ver al jugador un momento: Chase", Brain.next("Attack", brainCtx({ targetLostFor = 0.5 })) == "Chase")
check("Attack pierde al jugador y va a Investigate", Brain.next("Attack", brainCtx({ targetLostFor = 3 })) == "Investigate")
check("un estado desconocido cae a Idle", Brain.next("Inventado", brainCtx({})) == "Idle")

-- Infectados: movimiento y ataque con el jugador real -----------------------------
section("Infectados: movimiento y ataque")
local function waitForAlivePlayer(timeout)
	local startedAt = os.clock()
	while os.clock() - startedAt < timeout do
		local playerCharacter = testPlayer and testPlayer.Character
		local hum = playerCharacter and playerCharacter:FindFirstChildOfClass("Humanoid")
		local rootPart = playerCharacter and playerCharacter:FindFirstChild("HumanoidRootPart")
		if hum and rootPart and hum.Health > 0 then
			return playerCharacter, hum, rootPart
		end
		task.wait(0.25)
	end
	return nil
end

local playerCharacter, playerHumanoid, playerRoot = waitForAlivePlayer(20)
if ZombieSvc and playerCharacter then
	task.wait(1)
	local base = playerRoot.Position
	local function flat(a, b)
		return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
	end

	-- Lejos del jugador (más de 16 studs): deambula e investiga.
	local wanderer = ZombieSvc:Spawn("Walker", base + Vector3.new(0, 0, -90))
	local investigator = ZombieSvc:Spawn("Walker", base + Vector3.new(-90, 0, 0))
	local wandererStart = wanderer.HumanoidRootPart.Position
	local investigatorStart = investigator.HumanoidRootPart.Position
	local investigatePoint = investigatorStart + Vector3.new(25, 0, 0)
	check("un infectado nuevo empieza en Idle", ZombieSvc:GetState(wanderer) == "Idle")
	check("Investigate acepta la orden", ZombieSvc:Investigate(investigator, investigatePoint) == true)
	check("el infectado pasa a Investigate", ZombieSvc:GetState(investigator) == "Investigate")

	-- Cerca del jugador: persigue y ataca.
	playerHumanoid.Health = playerHumanoid.MaxHealth
	local chaser = ZombieSvc:Spawn("Walker", base + Vector3.new(14, 0, 0))
	-- Mirando al jugador: la visión tiene cono, así que debe verlo de frente.
	local chaserPosition = chaser.HumanoidRootPart.Position
	chaser:PivotTo(CFrame.lookAt(chaserPosition, Vector3.new(base.X, chaserPosition.Y, base.Z)))
	task.wait(1.5)
	local chaserState = ZombieSvc:GetState(chaser)
	check("ve al jugador cercano y lo persigue", chaserState == "Chase" or chaserState == "Attack", tostring(chaserState))

	local healthBefore = playerHumanoid.Health
	local attacked = false
	local deadline = os.clock() + 12
	while os.clock() < deadline do
		if ZombieSvc:GetState(chaser) == "Attack" and playerHumanoid.Health < healthBefore then
			attacked = true
			break
		end
		task.wait(0.25)
	end
	check("llega hasta el jugador y ataca", attacked)
	check("el ataque quita al menos el daño de su tipo", playerHumanoid.Health <= healthBefore - Zombies.Walker.damage)
	check("al atacar queda dentro del alcance", flat(chaser.HumanoidRootPart.Position, playerRoot.Position) <= AI.ATTACK_RANGE * 1.5)

	-- Un infectado muerto deja de atacar.
	ZombieSvc:Damage(chaser, 9999, testPlayer)
	task.wait(0.5)
	local healthAfterKill = playerHumanoid.Health
	task.wait(2)
	check("un infectado muerto ya no ataca", playerHumanoid.Health == healthAfterKill)

	-- Deambular: se mueve solo cuando no hay nadie cerca.
	local moved = false
	deadline = os.clock() + 12
	while os.clock() < deadline do
		if (wanderer.HumanoidRootPart.Position - wandererStart).Magnitude > 2 then
			moved = true
			break
		end
		task.wait(0.5)
	end
	check("sin jugadores cerca, el infectado deambula", moved)

	-- Investigar: se acerca al punto indicado y luego se calma.
	local approached = false
	deadline = os.clock() + 12
	while os.clock() < deadline do
		if (investigator.HumanoidRootPart.Position - investigatePoint).Magnitude < 25 - 8 then
			approached = true
			break
		end
		task.wait(0.5)
	end
	check("el infectado se acerca al punto que investiga", approached)

	local calmed = false
	deadline = os.clock() + 15
	while os.clock() < deadline do
		if ZombieSvc:GetState(investigator) ~= "Investigate" then
			calmed = true
			break
		end
		task.wait(0.5)
	end
	check("al llegar al punto deja de investigar", calmed)
	check("investigar no se acepta en un infectado muerto", (function()
		local dummy = ZombieSvc:Spawn("Walker", base + Vector3.new(0, 0, -120))
		ZombieSvc:Damage(dummy, 9999, nil)
		return ZombieSvc:Investigate(dummy, base) == false
	end)())

	-- Limpieza
	playerHumanoid.Health = playerHumanoid.MaxHealth
	for _, child in workspace.Zombies:GetChildren() do
		if ZombieSvc:GetRecord(child) then
			ZombieSvc:Damage(child, 99999, nil)
		end
	end
	check("tras limpiar no quedan infectados vivos (IA)", ZombieSvc:CountActive() == 0)
else
	warn("[Test] FAIL no hay jugador vivo para probar la IA de infectados")
	failed += 1
end

-- Vision (matemática pura) -----------------------------------------------------------
section("Vision (pura)")
local Vision = require(Shared.Util.Vision)
local origin = Vector3.new(0, 0, 0)
local facingForward = Vector3.new(0, 0, -1)
check("ve a quien está de frente y cerca", Vision.inFieldOfView(origin, facingForward, Vector3.new(0, 0, -20), 45, 110, 5) == true)
check("no ve a quien está de espaldas", Vision.inFieldOfView(origin, facingForward, Vector3.new(0, 0, 20), 45, 110, 5) == false)
check("no ve a quien está al costado a 90° con cono de 110°", Vision.inFieldOfView(origin, facingForward, Vector3.new(20, 0, 0), 45, 110, 5) == false)
check("ve dentro del cono a 40° del frente", Vision.inFieldOfView(origin, facingForward, Vector3.new(math.sin(math.rad(40)) * 20, 0, -math.cos(math.rad(40)) * 20), 45, 110, 5) == true)
check("no ve fuera del cono a 70° del frente", Vision.inFieldOfView(origin, facingForward, Vector3.new(math.sin(math.rad(70)) * 20, 0, -math.cos(math.rad(70)) * 20), 45, 110, 5) == false)
check("no ve más lejos que su alcance", Vision.inFieldOfView(origin, facingForward, Vector3.new(0, 0, -50), 45, 110, 5) == false)
check("nota a quien está pegado aunque esté detrás", Vision.inFieldOfView(origin, facingForward, Vector3.new(0, 0, 4), 45, 110, 5) == true)
check("la presencia cercana también respeta el alcance", Vision.inFieldOfView(origin, facingForward, Vector3.new(0, 0, 4), 3, 110, 5) == false)
check("alerta (360°) ve a quien está detrás", Vision.inFieldOfView(origin, facingForward, Vector3.new(0, 0, 30), 56, 360, 5) == true)
check("la altura no cambia el ángulo", Vision.inFieldOfView(origin, facingForward, Vector3.new(0, 15, -20), 45, 110, 5) == true)
check("un ruido dentro del radio se oye", Vision.heardNoise(Vector3.new(0, 0, 0), Vector3.new(0, 0, 20), 25) == true)
check("un ruido fuera del radio no se oye", Vision.heardNoise(Vector3.new(0, 0, 0), Vector3.new(0, 0, 30), 25) == false)
check("la sensibilidad amplía el oído", Vision.heardNoise(Vector3.new(0, 0, 0), Vector3.new(0, 0, 30), 25, 1.2) == true)
check("la sensibilidad baja lo reduce", Vision.heardNoise(Vector3.new(0, 0, 0), Vector3.new(0, 0, 22), 25, 0.8) == false)

-- Infectados: visión con paredes y oído -----------------------------------------------
section("Infectados: visión y oído")
local senseCharacter, senseHumanoid, senseRoot = waitForAlivePlayer(20)
if ZombieSvc and loaded.NoiseService and senseCharacter then
	task.wait(1)
	local base2 = senseRoot.Position
	local function faceTowards(model, targetPosition)
		local position = model.HumanoidRootPart.Position
		model:PivotTo(CFrame.lookAt(position, Vector3.new(targetPosition.X, position.Y, targetPosition.Z)))
	end
	local function isAlert(model)
		local state = ZombieSvc:GetState(model)
		return state == "Chase" or state == "Attack"
	end

	-- De espaldas no ve al jugador; al girarse, sí.
	local turnedAway = ZombieSvc:Spawn("Walker", base2 + Vector3.new(0, 0, 14))
	local awayPosition = turnedAway.HumanoidRootPart.Position
	turnedAway:PivotTo(CFrame.lookAt(awayPosition, awayPosition + Vector3.new(0, 0, 10))) -- mira lejos del jugador
	task.wait(0.8) -- menos que el mínimo de espera en Idle (2 s), para que no empiece a deambular
	check("de espaldas, el infectado no ve al jugador", not isAlert(turnedAway), tostring(ZombieSvc:GetState(turnedAway)))
	faceTowards(turnedAway, base2)
	task.wait(0.8)
	check("al girarse hacia el jugador, lo ve y persigue", isAlert(turnedAway), tostring(ZombieSvc:GetState(turnedAway)))
	ZombieSvc:Damage(turnedAway, 9999, nil)

	-- Una pared entre los dos bloquea la vista.
	senseHumanoid.Health = senseHumanoid.MaxHealth
	local behindWall = ZombieSvc:Spawn("Walker", base2 + Vector3.new(-14, 0, 0))
	faceTowards(behindWall, base2)
	local wall = Instance.new("Part")
	wall.Name = "TestWall"
	wall.Anchored = true
	wall.Size = Vector3.new(1, 14, 30)
	wall.Position = base2 + Vector3.new(-7, 4, 0)
	wall.Parent = workspace
	task.wait(0.8)
	check("con una pared en medio, no lo ve", not isAlert(behindWall), tostring(ZombieSvc:GetState(behindWall)))
	wall:Destroy()
	task.wait(0.8)
	check("sin la pared, lo ve y persigue", isAlert(behindWall), tostring(ZombieSvc:GetState(behindWall)))
	ZombieSvc:Damage(behindWall, 9999, nil)

	-- Oído: lejos del jugador (más de 56 studs), según radio y sensibilidad.
	local Noise = loaded.NoiseService
	local walkerEar = ZombieSvc:Spawn("Walker", base2 + Vector3.new(0, 0, -100))
	local runnerEar = ZombieSvc:Spawn("Runner", base2 + Vector3.new(-100, 0, 0))
	local walkerPos = walkerEar.HumanoidRootPart.Position
	local runnerPos = runnerEar.HumanoidRootPart.Position
	Noise:Emit(walkerPos + Vector3.new(30, 0, 0), 26, nil) -- Walker oye hasta 26; está a 30
	task.wait(0.3)
	check("el caminante no oye un ruido a 30 studs con radio 26", ZombieSvc:GetState(walkerEar) ~= "Investigate")
	Noise:Emit(runnerPos + Vector3.new(30, 0, 0), 26, nil) -- Runner oye hasta 31,2
	task.wait(0.3)
	check("el corredor, más sensible, sí lo oye", ZombieSvc:GetState(runnerEar) == "Investigate")
	Noise:Emit(walkerPos + Vector3.new(20, 0, 0), 26, nil)
	task.wait(0.3)
	check("el caminante oye un ruido a 20 studs", ZombieSvc:GetState(walkerEar) == "Investigate")

	-- Va hacia el origen del ruido.
	local noiseOrigin = runnerPos + Vector3.new(30, 0, 0)
	local startDistance = (runnerEar.HumanoidRootPart.Position - noiseOrigin).Magnitude
	task.wait(3)
	check("el infectado se acerca al origen del ruido", (runnerEar.HumanoidRootPart.Position - noiseOrigin).Magnitude < startDistance - 6)

	-- Un infectado que ya persigue ignora el ruido.
	local hunter = ZombieSvc:Spawn("Walker", base2 + Vector3.new(10, 0, 0))
	faceTowards(hunter, base2)
	task.wait(1)
	local hunterWasAlert = isAlert(hunter)
	Noise:Emit(hunter.HumanoidRootPart.Position + Vector3.new(5, 0, 0), 60, nil)
	task.wait(0.3)
	check("un infectado que persigue ignora los ruidos", hunterWasAlert and isAlert(hunter))

	-- Limpieza
	senseHumanoid.Health = senseHumanoid.MaxHealth
	for _, child in workspace.Zombies:GetChildren() do
		if ZombieSvc:GetRecord(child) then
			ZombieSvc:Damage(child, 99999, nil)
		end
	end
	check("tras limpiar no quedan infectados vivos (sentidos)", ZombieSvc:CountActive() == 0)
else
	warn("[Test] FAIL no hay jugador vivo para probar los sentidos")
	failed += 1
end

-- Infectados: golpes y bajas -----------------------------------------------------------
section("Infectados: golpes y bajas")
local hitCharacter, hitHumanoid, hitRoot = waitForAlivePlayer(20)
local DataSvc = loaded.DataService
if ZombieSvc and DataSvc and hitCharacter then
	task.wait(1)
	local base3 = hitRoot.Position
	local function stateIsAlert(model)
		local s = ZombieSvc:GetState(model)
		return s == "Chase" or s == "Attack"
	end

	-- Un golpe alerta a un infectado que no veía al jugador (de espaldas y a 25 studs).
	local sleeper = ZombieSvc:Spawn("Walker", base3 + Vector3.new(0, 0, 25))
	local sleeperPosition = sleeper.HumanoidRootPart.Position
	sleeper:PivotTo(CFrame.lookAt(sleeperPosition, sleeperPosition + Vector3.new(0, 0, 10)))
	task.wait(0.6)
	check("antes del golpe, de espaldas y lejos, no está alerta", not stateIsAlert(sleeper), tostring(ZombieSvc:GetState(sleeper)))
	check("un golpe no letal devuelve false", ZombieSvc:Damage(sleeper, 10, testPlayer) == false)
	check("el golpe lo alerta y persigue", ZombieSvc:GetState(sleeper) == "Chase", tostring(ZombieSvc:GetState(sleeper)))
	local lookVector = sleeper.HumanoidRootPart.CFrame.LookVector
	local toPlayer = Vector3.new(base3.X - sleeperPosition.X, 0, base3.Z - sleeperPosition.Z).Unit
	check("al ser golpeado se gira hacia quien lo golpeó", lookVector:Dot(toPlayer) > 0.9)

	-- Sin jugador que lo golpee (daño ambiental), no se alerta.
	local quiet = ZombieSvc:Spawn("Walker", base3 + Vector3.new(0, 0, -25))
	local quietPosition = quiet.HumanoidRootPart.Position
	quiet:PivotTo(CFrame.lookAt(quietPosition, quietPosition + Vector3.new(0, 0, -10)))
	ZombieSvc:Damage(quiet, 10, nil)
	check("un daño sin jugador no lo alerta", not stateIsAlert(quiet), tostring(ZombieSvc:GetState(quiet)))

	-- Aviso de muerte y estadísticas.
	local killed = {}
	ZombieSvc:OnKilled(function(model, killer, typeId)
		table.insert(killed, { model = model, killer = killer, typeId = typeId })
	end)
	local profile = DataSvc:Get(testPlayer)
	local killsBefore = profile.stats.zombiesKilled
	check("un golpe letal devuelve true", ZombieSvc:Damage(sleeper, 9999, testPlayer) == true)
	task.wait(0.2)
	check("OnKilled avisa con el modelo, quien mató y el tipo", #killed == 1 and killed[1].model == sleeper and killed[1].killer == testPlayer and killed[1].typeId == "Walker")
	check("la baja suma a las estadísticas del jugador", profile.stats.zombiesKilled == killsBefore + 1)

	ZombieSvc:Damage(quiet, 9999, nil)
	task.wait(0.2)
	check("una muerte sin jugador avisa con killer nil", #killed == 2 and killed[2].killer == nil)
	check("una muerte sin jugador no suma estadísticas", profile.stats.zombiesKilled == killsBefore + 1)
	check("un infectado muerto no vuelve a avisar", ZombieSvc:Damage(sleeper, 10, testPlayer) == false and #killed == 2)

	-- Limpieza
	hitHumanoid.Health = hitHumanoid.MaxHealth
	for _, child in workspace.Zombies:GetChildren() do
		if ZombieSvc:GetRecord(child) then
			ZombieSvc:Damage(child, 99999, nil)
		end
	end
	check("tras limpiar no quedan infectados vivos (golpes)", ZombieSvc:CountActive() == 0)
else
	warn("[Test] FAIL no hay jugador vivo para probar golpes y bajas")
	failed += 1
end

print(`[Test] RESULTADO: {passed} PASS, {failed} FAIL`)
