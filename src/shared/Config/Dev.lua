--!nonstrict
-- Interruptores solo para desarrollo en Studio. Los valores que se suben a Git son los
-- normales; cámbialos solo en tu copia y no los subas.

local Dev = {
	-- false = no corre la suite automática al dar Play (útil para jugar a mano sin esperar).
	RUN_SELF_TESTS = true,

	-- Id de un arma ("Bat", "Knife", "Pistol") que se entrega y equipa sola al aparecer.
	-- nil = ninguna. Sirve para ver las posturas y animaciones sin buscar el arma.
	-- Pon RUN_SELF_TESTS = false mientras la uses, para que las pruebas no la quiten.
	DEMO_WEAPON = nil,
	-- Si hay arma de demostración, ataca sola cada tantos segundos (nil = no ataca).
	DEMO_ATTACK_EVERY = nil,

	-- 1 = velocidad normal. Mayor que 1 hace las animaciones de armas más lentas, para
	-- poder verlas con calma o calibrar los ángulos.
	ANIMATION_TIME_SCALE = 1,

	-- true = WeaponAnimator escribe en la Salida cada postura que aplica.
	DEBUG_ANIMATION = false,
}

return Dev
