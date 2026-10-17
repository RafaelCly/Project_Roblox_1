--!nonstrict
-- Visión y oído puros (solo matemática de vectores, sin raycast ni Instances).
-- Las paredes se comprueban aparte, con un rayo, en ZombieService.

local Vision = {}

-- ¿Cae el objetivo dentro del campo de visión?
--   look       dirección hacia donde mira el observador (se usa en el plano horizontal)
--   range      distancia máxima de visión, en studs
--   angleDeg   ancho del cono en grados (360 o más = ve alrededor)
--   awareRange dentro de esta distancia lo nota aunque esté fuera del cono (presencia cercana)
function Vision.inFieldOfView(origin: Vector3, look: Vector3, target: Vector3, range: number, angleDeg: number, awareRange: number?): boolean
	local toTarget = target - origin
	local distance = toTarget.Magnitude
	if distance > range then
		return false
	end
	if awareRange and distance <= awareRange then
		return true
	end
	if angleDeg >= 360 then
		return true
	end

	local flatLook = Vector3.new(look.X, 0, look.Z)
	local flatTo = Vector3.new(toTarget.X, 0, toTarget.Z)
	if flatLook.Magnitude < 1e-6 or flatTo.Magnitude < 1e-6 then
		return true
	end

	local cosine = flatLook.Unit:Dot(flatTo.Unit)
	return cosine >= math.cos(math.rad(angleDeg / 2))
end

-- ¿Oye el oyente un ruido de ese radio? multiplier es la sensibilidad del tipo de infectado.
function Vision.heardNoise(listener: Vector3, noisePosition: Vector3, radius: number, multiplier: number?): boolean
	return (listener - noisePosition).Magnitude <= radius * (multiplier or 1)
end

return Vision
