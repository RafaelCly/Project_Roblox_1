--!nonstrict
-- Pruebas con 2 jugadores reales. Solo corren dentro de Roblox Studio, y solo si entran
-- 2 jugadores (Prueba > Clientes y servidores > 2 jugadores > Iniciar).
-- Con 1 jugador este script no hace nada. Si el segundo jugador está desde el inicio,
-- SelfTest se aparta; si llega más tarde, esperan a que SelfTest termine (atributo
-- SelfTestDone del Workspace) para no interferir con la suite de 1 jugador.
-- Resultado en la ventana Output del servidor: busca "[TestMulti]".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

if not RunService:IsStudio() then
	return
end

-- Espera a que haya 2 jugadores Y a que SelfTest termine su suite (o se aparte). El segundo
-- cliente puede entrar desde el inicio o más tarde (Prueba > Añadir clientes).
local deadline = os.clock() + 900
while os.clock() < deadline do
	if #Players:GetPlayers() >= 2 and workspace:GetAttribute("SelfTestDone") then
		break
	end
	task.wait(1)
end
if #Players:GetPlayers() < 2 or not workspace:GetAttribute("SelfTestDone") then
	return
end
task.wait(5) -- que Main inicie los servicios y los personajes aparezcan

local Shared = ReplicatedStorage:WaitForChild("Shared")
local services = script.Parent:WaitForChild("Services")
local Inventory = require(services.InventoryService)
local Survival = require(services.SurvivalService)
local ZombieSvc = require(services.ZombieService)
local DataSvc = require(services.DataService)
local Combat = require(services.CombatService)
local Weapons = require(Shared.Config.Weapons)
local SurvivalConfig = require(Shared.Config.Survival)

local passed, failed = 0, 0

local function check(name: string, condition: boolean, detail: string?)
	if condition then
		passed += 1
		print(`[TestMulti] PASS {name}`)
	else
		failed += 1
		warn(`[TestMulti] FAIL {name}{detail and (" - " .. detail) or ""}`)
	end
end

local function section(name: string)
	print(`[TestMulti] ---- {name}`)
end

local function waitAlive(player: Player, timeout: number)
	local startedAt = os.clock()
	while os.clock() - startedAt < timeout do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and humanoid.Health > 0 then
			for _, child in character:GetChildren() do
				if child:IsA("ForceField") then
					child:Destroy() -- el escudo de reaparición bloquea el daño
				end
			end
			return character, humanoid, root
		end
		task.wait(0.25)
	end
	return nil
end

local function countOf(player: Player, id: string): number
	return Inventory:Count(player, id)
end

local function slotOf(player: Player, id: string)
	local inventory = Inventory:Get(player)
	for i = 1, inventory.slotCount do
		if inventory.slots[i] and inventory.slots[i].id == id then
			return i
		end
	end
	return nil
end

local function shield(character: Model): ForceField
	local forceField = Instance.new("ForceField")
	forceField.Visible = false
	forceField.Parent = character
	return forceField
end

local players = Players:GetPlayers()
local p1, p2 = players[1], players[2]

-- Personajes nuevos: SurvivalService reinicia su estado con cada personaje (solo se cae
-- una vez), y el jugador 1 pudo haber caído ya en la suite de 1 jugador.
p1:LoadCharacter()
p2:LoadCharacter()
task.wait(2)

local character1, humanoid1, root1 = waitAlive(p1, 20)
local character2, humanoid2, root2 = waitAlive(p2, 20)

if not (character1 and character2) then
	warn("[TestMulti] FAIL los dos jugadores deben estar vivos para empezar")
	print("[TestMulti] RESULTADO MULTIJUGADOR: 0 PASS, 1 FAIL")
	return
end

-- Zona lejos de la casa de prueba y del punto de aparición.
local base = Vector3.new(-150, 5, -150)
local function teleport(character: Model, position: Vector3)
	character:PivotTo(CFrame.new(position))
	task.wait(0.6)
end
teleport(character1, base)
teleport(character2, base + Vector3.new(5, 0, 0))

-- Cada jugador tiene lo suyo -----------------------------------------------------
section("Cada jugador tiene lo suyo")
check("hay dos jugadores distintos", p1 ~= p2 and p1.UserId ~= p2.UserId)
check("cada uno tiene su inventario", Inventory:Get(p1) ~= nil and Inventory:Get(p2) ~= nil and Inventory:Get(p1) ~= Inventory:Get(p2))
Inventory:AddItem(p1, "Bandage", 1)
check("un objeto del jugador 1 no aparece en el 2", countOf(p1, "Bandage") == 1 and countOf(p2, "Bandage") == 0)
Survival:SetHunger(p1, 40)
check("el hambre de uno no cambia la del otro", math.abs(Survival:GetHunger(p1) - 40) < 2 and Survival:GetHunger(p2) > 90)
Survival:SetHunger(p1, 100)
check("cada jugador tiene su propio perfil", DataSvc:Get(p1) ~= nil and DataSvc:Get(p2) ~= nil and DataSvc:Get(p1) ~= DataSvc:Get(p2))

-- Pasar objetos -----------------------------------------------------------------------
section("Pasar objetos entre jugadores")
check("pasar un objeto a un compañero cercano", Inventory:GiveSlot(p1, slotOf(p1, "Bandage"), p2.UserId) == true)
check("el objeto cambió de dueño", countOf(p1, "Bandage") == 0 and countOf(p2, "Bandage") == 1)
Inventory:AddItem(p1, "Cloth", 2)
teleport(character2, base + Vector3.new(40, 0, 0))
check("no se puede pasar un objeto a un compañero lejano", Inventory:GiveSlot(p1, slotOf(p1, "Cloth"), p2.UserId) == false)
check("lo rechazado no mueve nada", countOf(p1, "Cloth") == 2 and countOf(p2, "Cloth") == 0)
teleport(character2, base + Vector3.new(5, 0, 0))
Inventory:RemoveItem(p1, "Cloth", 2)
Inventory:RemoveItem(p2, "Bandage", 1)

-- Recoger lo que suelta otro jugador ---------------------------------------------------------
section("Recoger lo que suelta el compañero")
Inventory:AddItem(p1, "Knife", 1)
check("el jugador 1 suelta un cuchillo", Inventory:DropSlot(p1, slotOf(p1, "Knife")) == true)
local pickups = workspace:FindFirstChild("Pickups")
local dropped
for _, pickup in pickups:GetChildren() do
	if pickup:GetAttribute("ItemId") == "Knife" then
		dropped = pickup
	end
end
check("el cuchillo aparece en el suelo", dropped ~= nil)
if dropped then
	check("el jugador 2 puede recogerlo", Inventory:_collect(p2, dropped) == true and countOf(p2, "Knife") == 1 and countOf(p1, "Knife") == 0)
end
Inventory:RemoveItem(p2, "Knife", 1)

-- Un compañero en la línea de fuego no frena la bala ---------------------------------------------
section("Disparo con un compañero en la línea")
local shotShield1, shotShield2 = shield(character1), shield(character2)
teleport(character1, base)
teleport(character2, base + Vector3.new(0, 0, -6)) -- justo delante del tirador
local aimDirection = Vector3.new(0, 0, -1)
Inventory:AddItem(p1, "Pistol", 1)
Inventory:AddItem(p1, "PistolAmmo", 20)
Combat:Equip(p1, "Pistol")
Combat:_setMagazine(p1, "Pistol", Weapons.Pistol.magazineSize)
local shotTarget = ZombieSvc:Spawn("Walker", Vector3.new(base.X, 0, base.Z - 20)) -- detrás del compañero
task.wait(0.4)
local targetHumanoid = shotTarget and shotTarget:FindFirstChildOfClass("Humanoid")
local mateHealthBefore = humanoid2.Health
local shotOk, shotHits = Combat:Attack(p1, aimDirection, root1.Position)
check("el disparo atraviesa al compañero y acierta al infectado", shotOk == true and shotHits == 1, `ok={tostring(shotOk)} hits={tostring(shotHits)}`)
check("el infectado detrás del compañero pierde vida", targetHumanoid ~= nil and targetHumanoid.Health < targetHumanoid.MaxHealth)
check("el compañero no recibe daño del disparo", humanoid2.Health == mateHealthBefore, tostring(humanoid2.Health))
Combat:Unequip(p1)
Inventory:RemoveItem(p1, "Pistol", 1)
local ammoLeft = countOf(p1, "PistolAmmo")
if ammoLeft > 0 then
	Inventory:RemoveItem(p1, "PistolAmmo", ammoLeft)
end
if shotTarget then
	ZombieSvc:Damage(shotTarget, 99999, nil)
end
shotShield1:Destroy()
shotShield2:Destroy()

-- Infectados con dos jugadores -----------------------------------------------------------------
section("Infectados con dos jugadores")
local shield1, shield2 = shield(character1), shield(character2)
-- El infectado mira hacia -X con el jugador 1 a 8 studs y el 2 a 16 studs.
local zombieX = base.X + 30
teleport(character1, Vector3.new(zombieX - 8, 5, base.Z))
teleport(character2, Vector3.new(zombieX - 16, 5, base.Z))
local zombie = ZombieSvc:Spawn("Walker", Vector3.new(zombieX, 0, base.Z))
local zombiePosition = zombie.HumanoidRootPart.Position
zombie:PivotTo(CFrame.lookAt(zombiePosition, zombiePosition + Vector3.new(-10, 0, 0)))
task.wait(1.2)
local record = ZombieSvc:GetRecord(zombie)
check("el infectado ve a los jugadores y se alerta", ZombieSvc:GetState(zombie) == "Chase" or ZombieSvc:GetState(zombie) == "Attack", tostring(ZombieSvc:GetState(zombie)))
check("elige al jugador más cercano", record.target == p1, tostring(record.target))

-- Un caído deja de ser el objetivo preferido: el infectado va a por el otro.
check("el jugador 1 cae en lugar de morir", Survival:Damage(p1, 500, nil) == "downed" and Survival:IsDowned(p1) == true)
task.wait(1.2)
check("el infectado prefiere al jugador que no está caído", record.target == p2, tostring(record.target))
check("el caído sigue vivo: no lo remató mientras había otro objetivo", Survival:IsDowned(p1) == true and humanoid1.Health > 0)

-- Un infectado muerto por el jugador 2 suma solo a sus estadísticas.
local kills1, kills2 = DataSvc:Get(p1).stats.zombiesKilled, DataSvc:Get(p2).stats.zombiesKilled
check("el jugador 2 mata al infectado", ZombieSvc:Damage(zombie, 9999, p2) == true)
task.wait(0.3)
check("la baja suma solo al jugador que la hizo", DataSvc:Get(p2).stats.zombiesKilled == kills2 + 1 and DataSvc:Get(p1).stats.zombiesKilled == kills1)

-- Levantar a un compañero ---------------------------------------------------------------------------
section("Levantar a un compañero")
shield1:Destroy()
shield2:Destroy()
teleport(character1, base)
teleport(character2, base + Vector3.new(40, 0, 0))
check("el jugador 1 sigue caído", Survival:IsDowned(p1) == true)
check("nadie se levanta a sí mismo", Survival:Revive(p1, p1) == false and Survival:IsDowned(p1) == true)
check("un compañero lejano no puede levantarlo", Survival:Revive(p2, p1) == false and Survival:IsDowned(p1) == true)
teleport(character2, base + Vector3.new(5, 0, 0))
check("no se levanta a quien no está caído", Survival:Revive(p1, p2) == false)
check("un compañero cercano lo levanta", Survival:Revive(p2, p1) == true and Survival:IsDowned(p1) == false)
check("al levantarse recupera 30 de vida", humanoid1.Health == SurvivalConfig.REVIVE_HEALTH, tostring(humanoid1.Health))
check("solo se cae una vez: la segunda vez es mortal", Survival:Damage(p1, 500, nil) == "dead" and humanoid1.Health <= 0)

-- Limpieza
for _, child in workspace.Zombies:GetChildren() do
	if ZombieSvc:GetRecord(child) then
		ZombieSvc:Damage(child, 99999, nil)
	end
end

print(`[TestMulti] RESULTADO MULTIJUGADOR: {passed} PASS, {failed} FAIL`)
