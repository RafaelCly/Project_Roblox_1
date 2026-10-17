# Plan de la semana 2: armas, infectados y caídos

Objetivo de la semana: **un jugador puede pelear contra infectados que lo persiguen, y un compañero puede levantarlo una vez.** Al terminar, dos jugadores en la casa de prueba deben poder sobrevivir a un grupo de infectados usando cuchillo, bate y pistola.

Reparto: **Axel** hace el lado del jugador (armas, daño y caído). **Rafael** hace el lado del infectado (aparición, IA y ataque). Se encuentran en un contrato de funciones definido abajo, así ninguno depende del código del otro para empezar.

Ramas: Axel trabaja en `dev-axel`, Rafael en `dev-rafael`. Antes de empezar, cada uno hace `git merge main`. Al terminar un hito, *pull request* hacia `main` y el otro lo revisa.

---

## 1. Contrato entre los dos (acordado desde el día 1)

Estas son las únicas funciones que cruzan de un lado al otro. Si alguien necesita cambiarlas, avisa antes.

| Función | La implementa | La usa | Qué hace |
|---|---|---|---|
| `NoiseService:Emit(position, radius, source)` | Ya existe | Axel (armas, correr) y Rafael (escucha) | Avisa de un ruido en una posición. |
| `NoiseService:Subscribe(callback)` | Ya existe | Rafael | Los infectados oyen el ruido. |
| `ZombieService:Damage(zombieModel, amount, source)` | **Rafael** | Axel | Resta vida a un infectado. `source` es el jugador que atacó. Devuelve `true` si lo mató. |
| `ZombieService:FromInstance(instance)` | **Rafael** | Axel | Dado un objeto que recibió un golpe (parte o modelo), devuelve el modelo del infectado o `nil`. |
| `SurvivalService:Damage(player, amount, source)` | **Axel** | Rafael | Resta vida a un jugador. Aquí vive la regla de "caído" en lugar de morir. |
| `SurvivalService:IsDowned(player)` | **Axel** | Rafael | Los infectados deciden si siguen atacando a un jugador caído. |

Regla: los infectados atacan llamando a `SurvivalService:Damage`, nunca a `Humanoid:TakeDamage` directamente.

---

## 2. Trabajo de Axel: armas y caído

### 2.1 Equipar armas (día 1)
- Al usar una ranura con un objeto de tipo `Weapon`, el jugador **equipa** esa arma. Se actualiza `InventoryService:UseSlot` para llamar a `CombatService:Equip(player, itemId)`.
- Un arma equipada se ve en la mano del personaje: una pieza simple (cubo largo para el cuchillo y el bate, otro para la pistola) soldada a la mano. Sin arte final.
- Solo hay un arma equipada a la vez. Usar otra ranura de arma la cambia. Soltar el arma equipada la desequipa.

### 2.2 Ataque cuerpo a cuerpo: cuchillo y bate (día 2)
- Clic izquierdo con un arma cuerpo a cuerpo envía `RequestAttack` al servidor con la dirección a la que mira el jugador.
- El servidor comprueba: el jugador está vivo, no está caído, el arma está equipada, ya pasó el `cooldown` de `Config/Weapons`.
- El golpe busca infectados en un cono frente al jugador dentro de `range` (con `workspace:GetPartBoundsInRadius` o `Raycast`) y llama a `ZombieService:Damage`.
- El bate pierde durabilidad en cada golpe y se rompe en 0 (desaparece del inventario).
- Emite ruido con `NoiseService:Emit(posición, weapon.noiseRadius, player)`.

### 2.3 Pistola (día 3)
- Clic izquierdo dispara un rayo desde la cámara hacia donde apunta el jugador.
- **El servidor valida todo:** munición, `cooldown`, recarga en curso, y que el rayo del servidor impacte. El cliente solo muestra el disparo al instante (efecto y sonido).
- Munición: el cargador (`magazineSize`) se llena con `PistolAmmo` del inventario. La tecla `R` recarga (`RequestReload`) y tarda `reloadTime`.
- Estado de munición en el HUD (`HudController`): `cargador / reserva`.
- El disparo emite mucho ruido (radio 120).

### 2.4 Estado de caído y levantar (día 4)
- En `SurvivalService:Damage`: si el jugador **no ha caído antes en esta partida** y su vida llegaría a 0, en lugar de morir queda **caído**: vida fija en 1, no puede moverse rápido (WalkSpeed 4), no puede atacar ni usar objetos.
- Un caído tiene `DOWNED_SECONDS` (45) para que un compañero lo levante. Si se acaba el tiempo, muere.
- Un compañero cerca (a menos de 6 studs, vivo y no caído) mantiene pulsado un `ProximityPrompt` "Levantar" durante 3 segundos. El caído se levanta con 30 de vida.
- **Solo una vez por jugador y por partida** (`REVIVES_PER_PLAYER = 1`). La segunda vez que cae, muere.
- Si un caído muere, suelta su inventario (ya existe).
- El cliente muestra un aviso "Estás caído, espera ayuda" y una cuenta regresiva.

### 2.5 Pruebas de Axel
Añadir a `SelfTest.server.lua`:
- Equipar un arma la deja equipada y solo una a la vez.
- Un ataque antes del `cooldown` se rechaza.
- Un ataque con un arma que no está equipada se rechaza.
- La pistola sin munición no dispara; con munición, gasta una bala.
- Recargar mueve munición del inventario al cargador y respeta el tamaño.
- El bate se rompe al llegar a durabilidad 0.
- Recibir daño mortal por primera vez deja al jugador caído, no muerto.
- Un jugador caído no puede atacar.
- Un caído sin ayuda muere al agotar el tiempo.
- Levantar devuelve al jugador a 30 de vida, y la segunda caída es mortal.

---

## 3. Trabajo de Rafael: infectados

### 3.1 Modelo y aparición (día 1)
- Crear el modelo base de infectado: personaje R15 con `Humanoid`, piel verdosa y ropa gris. Se genera una vez con `Players:CreateHumanoidModelFromDescription` y se clona.
- `ZombieService:Spawn(typeId, position)` crea un infectado desde `Config/Zombies` (caminante, corredor, bruto) con su vida y velocidad.
- Los infectados viven en `workspace.Zombies`. El servidor es el dueño de la física (`SetNetworkOwner(nil)`).
- Límite de infectados activos: `Config/Run.MAX_ACTIVE_ZOMBIES`.
- En Studio, un comando de desarrollo (`workspace:SetAttribute("DevSpawnZombies", 5)`) aparece 5 infectados cerca de la casa de prueba, para probar sin esperar oleadas.

### 3.2 Máquina de estados y movimiento (día 2)
Estados: `Inactivo → Deambular → Investigar → Perseguir → Atacar`.
- **Deambular:** camina a puntos al azar cerca de su origen, con pausas.
- **Investigar:** va hacia un ruido o hacia el último punto donde vio a un jugador. Si no encuentra nada en unos segundos, vuelve a deambular.
- **Perseguir:** sigue al jugador más cercano visible. Usa `PathfindingService` si hay un obstáculo y `Humanoid:MoveTo` en línea recta si no.
- **Atacar:** si está a menos de 4 studs, golpea cada `attackCooldown` con `SurvivalService:Damage`.
- Un solo ciclo de IA por infectado, con paso de 0.2 segundos (no cada frame), para cuidar el rendimiento.

### 3.3 Visión y oído (día 3)
- **Visión:** cono de `sightAngle` grados y `sightRange` studs frente al infectado. Además, un rayo hacia el jugador no debe chocar con paredes. Un jugador agachado se ve a la mitad de distancia (opcional, solo si da tiempo).
- **Oído:** suscripción a `NoiseService`. Si la distancia al ruido es menor que `radius * hearingMultiplier`, pasa a `Investigar` hacia el origen.
- Un infectado que pierde de vista a su objetivo va a `Investigar` hacia el último punto conocido.

### 3.4 Daño recibido y muerte (día 4)
- `ZombieService:Damage` resta vida, hace que el infectado mire hacia quien lo golpeó, y si llega a 0, lo marca como muerto, desactiva su IA y lo elimina tras 3 segundos.
- `ZombieService:FromInstance` sube por el árbol del objeto hasta encontrar un modelo dentro de `workspace.Zombies`.
- Un infectado ignora a un jugador caído (`SurvivalService:IsDowned`) si hay otro jugador vivo cerca.

### 3.5 Pruebas de Rafael
Añadir a `SelfTest.server.lua`:
- `Spawn` crea un modelo con la vida y velocidad del tipo pedido.
- No se superan los `MAX_ACTIVE_ZOMBIES`.
- Un ruido dentro del radio lleva al infectado a `Investigar`; un ruido fuera no.
- Un jugador dentro del cono de visión es detectado; uno detrás del infectado no.
- Un jugador detrás de una pared no es detectado.
- Un infectado cerca del jugador le quita vida a través de `SurvivalService:Damage`.
- `Damage` mata al infectado al llegar a 0 y devuelve `true`.
- `FromInstance` devuelve el modelo desde una de sus partes y `nil` para otra cosa.
- Un infectado pierde el interés y vuelve a deambular si no encuentra nada.

---

## 4. Calendario

| Día | Axel | Rafael |
|---|---|---|
| 1 | Equipar armas, armas visibles | Modelo, `Spawn`, límite, comando de desarrollo |
| 2 | Cuerpo a cuerpo y durabilidad | Máquina de estados y movimiento |
| 3 | Pistola, munición y recarga, HUD | Visión y oído |
| 4 | Caído y levantar | Daño recibido, muerte y `FromInstance` |
| 5 | **Integración juntos** | **Integración juntos** |

Día 5, juntos: probar con **2 jugadores reales** (Team Create o dos instancias de Studio con `Prueba → Iniciar servidor y 2 jugadores`). Revisar el rendimiento con 30 infectados, afinar el balance en `Config/` y corregir lo que falle.

## 5. Criterio de "terminado"

La semana está terminada cuando **todo** esto es cierto:
1. Con 5 infectados cerca, un jugador puede matarlos usando cuchillo, bate o pistola.
2. Los infectados persiguen al ver al jugador, y también cuando oyen un disparo.
3. Agacharse o esconderse detrás de una pared hace que pierdan al jugador.
4. Un infectado que golpea al jugador le quita vida y puede dejarlo caído.
5. Un compañero puede levantar al caído una sola vez.
6. Todas las pruebas automáticas pasan en Studio, sin ningún `FAIL`.
7. Se probó con 2 jugadores reales y con 30 infectados a la vez sin que baje de 30 FPS en el servidor.

## 6. Fuera de esta semana
Oleadas programadas, búnker, lobby y matchmaking, tienda, mapa modular, tipos especiales de infectados y resistencia (correr). Eso entra desde la semana 3.

## 7. Riesgos de esta semana

| Riesgo | Qué hacer |
|---|---|
| El combate se siente mal | Probarlo desde el día 2, no el día 5. Ajustar `Config/Weapons`. |
| Rendimiento con muchos infectados | Paso de IA de 0.2 s, límite de activos, pathfinding solo cuando hace falta. |
| El cliente y el servidor no coinciden al disparar | El servidor decide el impacto. El cliente solo muestra el efecto. |
| Pisarse en Git | Cada uno toca solo sus servicios. Los cambios compartidos (`Remotes`, `Config`) se avisan antes. |
| Rojo se cae al cambiar `default.project.json` | Desconectar Rojo en Studio antes de cambiar ese archivo. |
