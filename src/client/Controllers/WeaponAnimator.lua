--!nonstrict
-- WeaponAnimator
-- Postura y animación del brazo derecho de TODOS los jugadores con arma equipada.
-- Cada cliente anima lo que ve; el servidor solo avisa con atributos del jugador:
--   EquippedWeapon  qué arma lleva (id de objeto, por ejemplo "Bat")
--   Reloading       recargando la pistola
--   Downed          caído (baja el arma)
--   AttackSeq       contador que sube con cada ataque aceptado (golpe o disparo)
--
-- Cómo anima: crea por código una KeyframeSequence que mueve solo el hombro y el codo
-- derechos (R15), la registra con KeyframeSequenceProvider y la reproduce con prioridad
-- Action, por encima de las animaciones de caminar y quieto de Roblox. (Escribir
-- Motor6D.Transform o C0 a mano no sirve: Roblox lo sobrescribe o lo prohíbe.)
-- Solo personajes R15.
--
-- Ángulos en grados sobre el eje X: 0 = brazo colgando; 90 = brazo estirado hacia delante.
-- En el codo, un valor positivo levanta el antebrazo.

local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared:WaitForChild("Config"):WaitForChild("Items"))
local Dev = require(Shared:WaitForChild("Config"):WaitForChild("Dev"))

local WeaponAnimator = {}

local REST = { s = 0, e = 0 }
local TIME_SCALE = Dev.ANIMATION_TIME_SCALE or 1
local HOLD_FADE = 0.15

-- Posturas y ataques por arma. En attack, t = segundos que tarda en llegar a ese paso;
-- pose = "ready" significa volver a la postura de listo del arma.
local POSES = {
	Bat = {
		ready = { s = 55, e = 75 },
		attack = {
			{ t = 0.12, s = 165, e = 40 }, -- levanta el bate por encima de la cabeza
			{ t = 0.09, s = 20, e = 10 }, -- golpe hacia abajo
			{ t = 0.22, pose = "ready" },
		},
	},
	Knife = {
		ready = { s = 70, e = 55 },
		attack = {
			{ t = 0.05, s = 100, e = -5 }, -- estocada: el brazo se estira
			{ t = 0.2, pose = "ready" },
		},
	},
	Pistol = {
		ready = { s = 90, e = 0 },
		reload = { s = 50, e = 80 }, -- baja la pistola mientras recarga
		attack = {
			{ t = 0.04, s = 108, e = 0 }, -- retroceso: el brazo salta hacia arriba
			{ t = 0.16, pose = "ready" },
		},
	},
}

local animationIds = {} -- [clave] = id registrado (se comparte entre todos los personajes)
local rigs = {} -- [Player] = { character, animator, tracks, pose, ... }

local function debugLog(message: string)
	if Dev.DEBUG_ANIMATION then
		print(`[WeaponAnimator] {message}`)
	end
end

-- Construcción de animaciones -------------------------------------------------

local function newPose(name: string, cframe: CFrame, weight: number, parent: Instance)
	local pose = Instance.new("Pose")
	pose.Name = name
	pose.CFrame = cframe
	pose.Weight = weight
	pose.EasingStyle = Enum.PoseEasingStyle.Cubic
	pose.EasingDirection = Enum.PoseEasingDirection.Out
	pose.Parent = parent
	return pose
end

-- Un fotograma clave: solo RightUpperArm y RightLowerArm pesan; el resto es la cadena
-- jerárquica que exige R15 (HumanoidRootPart > LowerTorso > UpperTorso > brazo > antebrazo).
local function newKeyframe(time: number, s: number, e: number)
	local keyframe = Instance.new("Keyframe")
	keyframe.Time = time
	local root = newPose("HumanoidRootPart", CFrame.new(), 0, keyframe)
	local lower = newPose("LowerTorso", CFrame.new(), 0, root)
	local upper = newPose("UpperTorso", CFrame.new(), 0, lower)
	local arm = newPose("RightUpperArm", CFrame.Angles(math.rad(s), 0, 0), 1, upper)
	newPose("RightLowerArm", CFrame.Angles(math.rad(e), 0, 0), 1, arm)
	return keyframe
end

-- keyframes: lista de { time, s, e }. Devuelve el id registrado, o nil si falló.
local function registerSequence(name: string, loop: boolean, priority, keyframes)
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = name
	sequence.Loop = loop
	sequence.Priority = priority
	for _, kf in keyframes do
		newKeyframe(kf.time, kf.s, kf.e).Parent = sequence
	end
	local ok, result = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
	end)
	if not ok or not result then
		warn(`[WeaponAnimator] No se pudo registrar la animación {name}: {tostring(result)}`)
		return nil
	end
	debugLog(`animación {name} registrada`)
	return result
end

-- Postura mantenida: dos fotogramas iguales y en bucle.
local function holdId(weaponId: string, kind: string, pose)
	local key = `{weaponId}.{kind}`
	if animationIds[key] == nil then
		animationIds[key] = registerSequence(key, true, Enum.AnimationPriority.Action, {
			{ time = 0, s = pose.s, e = pose.e },
			{ time = 1, s = pose.s, e = pose.e },
		}) or false
	end
	return animationIds[key]
end

local function attackId(weaponId: string)
	local key = `{weaponId}.attack`
	if animationIds[key] == nil then
		local poses = POSES[weaponId]
		local keyframes = { { time = 0, s = poses.ready.s, e = poses.ready.e } }
		local clock = 0
		for _, step in poses.attack do
			clock += step.t
			local target = step.pose == "ready" and poses.ready or step
			table.insert(keyframes, { time = clock, s = target.s, e = target.e })
		end
		-- Prioridad mayor que la postura mantenida, para que el ataque la tape mientras dura.
		animationIds[key] = registerSequence(key, false, Enum.AnimationPriority.Action2, keyframes) or false
	end
	return animationIds[key]
end

local function loadTrack(rig, id)
	if not id then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, track = pcall(function()
		return rig.animator:LoadAnimation(animation)
	end)
	if not ok then
		warn(`[WeaponAnimator] No se pudo cargar la animación: {tostring(track)}`)
		return nil
	end
	return track
end

-- Pistas de un arma para un personaje (se crean al usarla por primera vez).
local function tracksFor(rig, weaponId: string)
	if rig.tracks[weaponId] then
		return rig.tracks[weaponId]
	end
	local poses = POSES[weaponId]
	local set = {
		ready = loadTrack(rig, holdId(weaponId, "ready", poses.ready)),
		reload = poses.reload and loadTrack(rig, holdId(weaponId, "reload", poses.reload)) or nil,
		attack = loadTrack(rig, attackId(weaponId)),
	}
	rig.tracks[weaponId] = set
	return set
end

-- Estado ---------------------------------------------------------------------

local function weaponIdOf(player: Player): string?
	local itemId = player:GetAttribute("EquippedWeapon")
	local item = itemId and Items[itemId]
	return item and POSES[item.weaponId] and item.weaponId or nil
end

local function stopAll(rig, exceptTrack)
	for _, set in rig.tracks do
		for _, track in set do
			if track ~= exceptTrack and track.IsPlaying then
				track:Stop(HOLD_FADE)
			end
		end
	end
end

-- Pone la postura que corresponde: arma lista, recargando, o nada (brazo libre).
local function refresh(player: Player)
	local rig = rigs[player]
	local weaponId = weaponIdOf(player)
	debugLog(`refresh {player.Name}: arma={tostring(weaponId)} rig={tostring(rig ~= nil)}`)
	if not rig then
		return
	end

	if not weaponId or player:GetAttribute("Downed") then
		stopAll(rig, nil)
		rig.pose = REST
		return
	end

	local set = tracksFor(rig, weaponId)
	local reloading = player:GetAttribute("Reloading") and set.reload ~= nil
	local hold = reloading and set.reload or set.ready
	local poses = POSES[weaponId]
	rig.pose = reloading and poses.reload or poses.ready

	stopAll(rig, hold)
	if hold and not hold.IsPlaying then
		hold:Play(HOLD_FADE, 1, 1 / TIME_SCALE)
		debugLog(`postura {reloading and "recargando" or "lista"} de {weaponId}`)
	end
end

local function playAttack(player: Player)
	local rig = rigs[player]
	local weaponId = weaponIdOf(player)
	if not rig or not weaponId or player:GetAttribute("Downed") then
		return
	end
	local attack = tracksFor(rig, weaponId).attack
	if attack then
		attack:Play(0.03, 1, 1 / TIME_SCALE)
		debugLog(`ataque de {weaponId}`)
	end
end

-- Registro de personajes --------------------------------------------------

local function buildRig(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid then
		return
	end
	debugLog(`buildRig {player.Name}: RigType={tostring(humanoid.RigType)}`)
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return -- solo R15
	end
	local animator = humanoid:WaitForChild("Animator", 10)
	if not animator or player.Character ~= character then
		return
	end

	rigs[player] = {
		character = character,
		animator = animator,
		tracks = {},
		pose = REST,
	}
	refresh(player)
end

local function trackPlayer(player: Player)
	-- AttackSeq ya puede valer algo: solo se anima cuando cambia a partir de ahora.
	local lastSeq = player:GetAttribute("AttackSeq") or 0

	for _, attribute in { "EquippedWeapon", "Reloading", "Downed" } do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			refresh(player)
		end)
	end
	player:GetAttributeChangedSignal("AttackSeq"):Connect(function()
		local seq = player:GetAttribute("AttackSeq") or 0
		if seq ~= lastSeq then
			lastSeq = seq
			playAttack(player)
		end
	end)

	player.CharacterAdded:Connect(function(character)
		rigs[player] = nil
		task.spawn(buildRig, player, character)
	end)
	if player.Character then
		task.spawn(buildRig, player, player.Character)
	end
end

-- Para las pruebas automáticas: postura objetivo del jugador ({ s, e } en grados).
function WeaponAnimator:GetPose(player: Player)
	local rig = rigs[player]
	return rig and rig.pose
end

-- Para las pruebas automáticas: cuántas pistas de arma se están reproduciendo.
function WeaponAnimator:CountPlaying(player: Player): number
	local rig = rigs[player]
	local count = 0
	if rig then
		for _, set in rig.tracks do
			for _, track in set do
				if track.IsPlaying then
					count += 1
				end
			end
		end
	end
	return count
end

function WeaponAnimator:Start()
	Players.PlayerAdded:Connect(trackPlayer)
	for _, player in Players:GetPlayers() do
		trackPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		rigs[player] = nil
	end)
end

return WeaponAnimator
