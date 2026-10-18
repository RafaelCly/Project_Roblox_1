# Plan de la semana 3: una partida completa de principio a fin

Objetivo de la semana: **en un solo servidor, de 2 a 4 jugadores pueden jugar una partida entera**: aparecen en un mapa generado, saquean, sobreviven a las oleadas, reúnen las piezas del búnker, defienden la puerta mientras se abre, y al final ven una pantalla de victoria o derrota. Todo se prueba en Studio.

Reparto: **Rafael** hace la partida (estados, oleadas, búnker y resultado). **Axel** hace el mundo (mapa modular, botín por zonas y ambiente). Se encuentran en un contrato de funciones definido abajo, así ninguno depende del código del otro para empezar.

Ramas: Rafael en `dev-rafael`, Axel en `dev-axel`. Antes de empezar, cada uno hace `git merge main`. Al terminar cada día, o cada pieza que funcione sola, *pull request* a `main` y el otro lo revisa.

## 0. Un cambio respecto al calendario original

`docs/diseno-mvp.md` (sección 9) ponía en la semana 3 "ruido, sigilo, oleada 1, mapa" y en la 4 "lobby, matchmaking, 3 oleadas y búnker". Ruido y sigilo ya se hicieron en la semana 2. Por eso este plan **adelanta las 3 oleadas y el búnker** a la semana 3 y **mueve el lobby, el matchmaking y el teletransporte a la semana 4**:

- Primero tiene que existir una partida que se pueda jugar; el lobby solo la reparte.
- El teletransporte entre servidores **no se puede probar en Studio** (solo funciona con el lugar publicado), así que es la parte más arriesgada y conviene dejarla para cuando lo demás ya esté estable.
- En Studio, la partida arranca con un comando de desarrollo (sección 5), sin lobby.

---

## 1. Contrato entre los dos

Estas son las funciones que cruzan de un lado al otro. Si alguien necesita cambiarlas, avisa antes.

| Función | La implementa | La usa | Qué hace |
|---|---|---|---|
| `MapService:Generate(seed)` | **Axel** | Rafael | Construye el mapa de la partida y devuelve un `MapInfo` (abajo). Una semilla igual da el mismo mapa. |
| `MapService:Clear()` | **Axel** | Rafael | Borra el mapa actual y todo lo que generó. |
| `LootService:PopulateAll()` | Ya existe (Axel) | Rafael | Reparte el botín en los puntos con la etiqueta `LootPoint` que dejó el mapa. |
| `MatchService:Begin(players)` | **Rafael** | Semana 4 (lobby) y el comando de desarrollo | Arranca una partida con esos jugadores. |
| `MatchService:OnEnded(callback)` | **Rafael** | Semana 4 (lobby) | `callback(resultado, datos)` al terminar. `resultado` es `"Won"` o `"Lost"`. |
| `MatchService:GetState()` | Ya existe | Todos | Estado actual de la partida. |

`MapInfo` es una tabla con estos campos:

| Campo | Tipo | Para qué |
|---|---|---|
| `playerSpawns` | lista de `Vector3` | Dónde aparecen los jugadores (al menos 4). |
| `zombieSpawns` | lista de `Vector3` | Dónde pueden aparecer infectados de oleada. Fuera de la vista de los jugadores al inicio. |
| `partPoints` | lista de `Vector3` | Sitios para esconder las 3 piezas del búnker (al menos 6, en edificios distintos). |
| `bunker` | tabla | `{ door = Part, doorPosition = Vector3, interior = Part }`: la puerta, su posición, y una parte que marca el interior (para saber quién está dentro). |

Regla: Rafael **nunca** construye geometría del mapa; Axel **nunca** decide cuándo empieza o termina una oleada.

### Cómo trabajar sin esperarse
- **Rafael** empieza con una versión falsa de `MapService:Generate` (un suelo plano con puntos alrededor del origen) escrita en su propia rama, y la reemplaza cuando llegue la de Axel. Si Axel ya subió la suya a `main`, la usa directamente.
- **Axel** prueba su mapa con un comando propio, sin `MatchService`: `workspace:SetAttribute("DevMap", 12345)` lo genera y imprime el `MapInfo`.

---

## 2. Trabajo de Rafael: la partida

### 2.1 Estados de la partida (día 1)
- `MatchService:Begin(players)` reúne a los jugadores, pide el mapa a `MapService:Generate`, coloca a cada jugador en un `playerSpawns`, y empieza el reloj de la partida (`RUN_DURATION_SECONDS`, 30 minutos).
- Estados (ya hay una lista en `MatchService.States`): `Lobby`, `Looting`, `Wave`, `BunkerDefense`, `Won`, `Lost`. Cada cambio avisa a los clientes con el remote `RunStateChanged` (ya existe) con el estado y el momento en que termina.
- **Reaparición:** durante una partida los jugadores **no reaparecen solos**. Se pone `Players.CharacterAutoLoads = false` al empezar y se carga a cada uno con `player:LoadCharacter()` en su punto de aparición. Un jugador muerto queda fuera hasta que acabe la partida, con el aviso "Has muerto, espera a tus compañeros".
- **Derrota:** si todos los jugadores han muerto, o el reloj llega a 0 sin victoria, el resultado es `Lost`.
- Al terminar: pausa de 8 segundos con el resultado en pantalla, `MapService:Clear()`, se borran los infectados y se restauran la reaparición y los inventarios.

### 2.2 Oleadas (días 2)
- `WaveService:Start(index)` lanza la oleada `index` de `Config/Run.Waves`. El número de infectados sale de un **presupuesto de dificultad**: cada tipo cuesta `budgetCost` (ya está en `Config/Zombies`); se llena el presupuesto con una mezcla (mayoría caminantes, algunos corredores, brutos desde la oleada 2). El presupuesto crece un 25% por cada jugador extra (`BUDGET_PER_EXTRA_PLAYER`).
- Los infectados aparecen **en grupos pequeños** (de 4 a 6 cada pocos segundos) en `zombieSpawns` elegidos lejos de los jugadores, nunca dentro de su vista, para no pasar de `MAX_ACTIVE_ZOMBIES`.
- Para los recién aparecidos, un ruido (`NoiseService:Emit`) los dirige hacia el centro del grupo de jugadores, así no se quedan quietos.
- Una oleada **termina** cuando ya aparecieron todos los de su presupuesto y no queda ninguno vivo. Se cuenta con `ZombieService:CountActive()` y el aviso `ZombieService:OnKilled`.
- Oleadas 1 y 2 por reloj (`startsAt`: 8:00 y 17:00). La oleada 3 **no** es por reloj: la dispara el búnker (ver 2.3). Hay que cambiar `Config/Run.Waves` en consecuencia (la tercera sin `startsAt`).
- Remote nuevo `WaveStarted` (ya existe) con el número de oleada y cuántos infectados trae, para el aviso en pantalla y la sirena.

### 2.3 Búnker (día 3)
- Tres objetos nuevos en `Config/Items`: **tarjeta de acceso**, **código** y **combustible**. No se pueden usar; solo se recogen y se entregan. Son de pila 1.
- Al empezar la partida, `BunkerService` coloca **una pieza de cada** en tres `partPoints` distintos y aleatorios, como recogibles (`InventoryService:SpawnPickup`). Si un jugador que las lleva muere, las suelta como cualquier objeto.
- En la puerta del búnker hay un `ProximityPrompt` "Insertar pieza". Cada vez que un jugador lo usa con una pieza en el inventario, la entrega y el panel de la puerta cuenta `1/3`, `2/3`, `3/3`. Las piezas pueden entregarlas jugadores distintos.
- Con `3/3` empieza la **defensa del búnker**: estado `BunkerDefense`, cuenta atrás de `BUNKER_DOOR_SECONDS` (90 s) con la oleada final (la 3) saliendo durante ese tiempo.
- Cuando la cuenta llega a 0 la puerta se abre. Hay una **ventana de 30 segundos** para entrar: gana el que esté dentro de `bunker.interior`. Si al menos uno está dentro al cerrarse la ventana, resultado `Won`; si no, `Lost`.

### 2.4 Pantalla de partida y resultado (día 4)
- Interfaz nueva: reloj de la partida, número de oleada, `1/3` de piezas y la cuenta atrás de la puerta.
- Pantalla de resultado con victoria o derrota, tiempo de partida e infectados derrotados.
- Al terminar se suman las estadísticas del perfil con `DataService` (`runsPlayed`, `runsWon`, `bestTimeSeconds`). `zombiesKilled` ya se suma solo.

### 2.5 Pruebas de Rafael
Añadir a `SelfTest.server.lua`:
- Una partida pasa por los estados en el orden esperado, y cada cambio de estado se avisa una sola vez.
- Los jugadores aparecen en puntos distintos de `playerSpawns`.
- Con el reloj acelerado (una variable de desarrollo para probar), las oleadas 1 y 2 empiezan a su hora.
- El presupuesto de una oleada nunca se pasa, y crece con el número de jugadores.
- Los infectados de oleada no aparecen a menos de N studs de ningún jugador.
- Una oleada termina solo cuando mueren todos sus infectados.
- Las 3 piezas aparecen en 3 puntos distintos y se pueden recoger.
- Entregar 3 piezas inicia `BunkerDefense`; con 2, no.
- Un jugador dentro del interior al abrirse la puerta da `Won`; ninguno dentro da `Lost`.
- Si todos mueren, resultado `Lost`.
- Al terminar queda el mapa borrado, sin infectados y la reaparición restaurada.

---

## 3. Trabajo de Axel: el mundo

### 3.1 Mapa modular (días 1 y 2)
- `MapService:Generate(seed)` construye **una cuadrícula de zonas** (por ejemplo 4×4, cada zona de unos 60×60 studs) con módulos elegidos al azar de una lista de **al menos 6 tipos**: calles, casas, gasolinera, comisaría, almacén, bosque, y la **zona del búnker** (siempre una, en un borde).
- Cada módulo se arma con **piezas simples por código** (como la `DevHouse`): suelo, paredes con puertas, techo, algo de decoración. Sin arte hecho a mano. Los edificios se pueden ir mejorando después.
- Las zonas se conectan por calles para que se pueda caminar entre todas. El camino hasta el búnker debe existir siempre.
- Devuelve `MapInfo` con `playerSpawns` (zona inicial segura, cerca del lado opuesto al búnker), `zombieSpawns`, `partPoints` y `bunker`.
- **Debe ser determinista**: la misma semilla da el mismo mapa.
- `MapService:Clear()` borra todo, sin dejar partes ni etiquetas sueltas.
- Debe generarse en menos de 3 segundos.

### 3.2 Botín por zonas (día 3)
- Cada tipo de módulo pone sus puntos `LootPoint` con su propia tabla en `Config/Loot` (casas: comida y telas; gasolinera: latas; comisaría: pistola y munición; almacén: materiales). Añadir las tablas que falten.
- `LootService:PopulateAll()` ya reparte; hay que comprobar que respeta las tablas nuevas y que **se puede llamar por segunda vez** (en otra partida) sin duplicar nada. Hay que limpiar los recogibles viejos al `Clear`.
- La zona de partida inicial debe tener muy poco botín, y las zonas lejanas más.

### 3.3 Ambiente (día 4)
- Iluminación y niebla que den tono Project Zomboid: poca luz, niebla corta, tonos fríos. Configurado al empezar la partida y restaurado al terminar.
- El interior de los edificios debe ser oscuro (un poco de luz puntual en algunos).
- Esto se hace con `Lighting`/`Atmosphere`, no con modelos.

### 3.4 Pruebas de Axel
Añadir a `SelfTest.server.lua` (o a un archivo de pruebas propio si crece mucho):
- `Generate` con la misma semilla dos veces da el mismo `MapInfo`.
- `Generate` con semillas distintas da mapas distintos.
- `MapInfo` trae al menos 4 `playerSpawns`, 6 `partPoints`, y ninguno cae dentro de una pared ni bajo el suelo.
- Hay camino caminable (con `PathfindingService`) entre un `playerSpawn` y la puerta del búnker, en 10 semillas distintas.
- Cada `zombieSpawn` está a más de N studs de todos los `playerSpawns`.
- `Clear` deja el Workspace igual que antes (sin partes, sin etiquetas `LootPoint`, sin recogibles).
- `PopulateAll` dos veces seguidas con un `Clear` en medio no duplica botín.
- Generar y limpiar 20 veces seguidas no deja basura ni sube la memoria de forma notable.

---

## 4. Calendario

| Día | Rafael | Axel |
|---|---|---|
| 1 | `MatchService:Begin`, estados y reloj; mapa falso para probar; reaparición manual | `Generate` con la cuadrícula y 3 o 4 tipos de módulo; `Clear` |
| 2 | `WaveService` con presupuesto y grupos; oleadas 1 y 2 por reloj | Resto de módulos (hasta 6+), caminos, zona del búnker, semilla determinista |
| 3 | `BunkerService`: piezas, puerta, cuenta atrás, ventana de salida | Botín por zonas y limpieza de `PopulateAll`; `playerSpawns` y `zombieSpawns` seguros |
| 4 | Interfaz de partida, resultado, estadísticas, limpieza al terminar | Ambiente (iluminación y niebla); pulido del mapa |
| 5 | **Integración juntos** | **Integración juntos** |

Día 5, juntos: una partida completa en Studio, primero con 1 jugador y luego con 2 (**Prueba → Servidor y cliente(s)**, como en el README). Ajustar la dificultad en `Config/`, medir el rendimiento con el mapa completo y 30 infectados, y corregir lo que falle.

## 5. Cómo se arranca una partida en Studio

Rafael añade un comando de desarrollo, igual que `DevSpawnZombies`. Con el juego en marcha, en la barra de comandos de la pestaña **Servidor**:

```lua
workspace:SetAttribute("DevStartMatch", true)
```

Eso llama a `MatchService:Begin(todos los jugadores)`. Para probar sin esperar 8 minutos hay un interruptor en `Config/Dev.lua` (`MATCH_TIME_SCALE`, que Rafael agrega): con 20 el reloj va 20 veces más rápido.

## 6. Criterio de "terminado"

La semana está terminada cuando **todo** esto es cierto:
1. `DevStartMatch` genera un mapa distinto cada vez, coloca a los jugadores y empieza la partida.
2. Las oleadas 1 y 2 llegan a su hora, con un aviso y una sirena, y no se pasan de `MAX_ACTIVE_ZOMBIES`.
3. Las 3 piezas se pueden encontrar, recoger y entregar en la puerta, aunque las reúnan jugadores distintos.
4. Con `3/3` empieza la defensa de 90 segundos con la oleada final, y la puerta se abre al terminar.
5. Entrar al búnker da victoria, y que todos mueran o se acabe el tiempo da derrota. Ambas muestran su pantalla.
6. Al terminar, el mapa se borra, no quedan infectados y se puede empezar otra partida sin reiniciar el servidor.
7. Se jugó una partida entera con 1 jugador y otra con 2 jugadores reales.
8. Todas las pruebas automáticas pasan en Studio, sin ningún `FAIL`.

## 7. Fuera de esta semana (semana 4 en adelante)
- **Lobby y salas de espera**, formación de grupos, **matchmaking** y **teletransporte** a un servidor reservado (`TeleportService:ReserveServer`). Para probarlo hay que **publicar el lugar** y activar *Habilitar acceso de Studio a servicios de API*.
- Servidores privados, tienda y compras (Game Passes y Developer Products).
- Tipos nuevos de infectados, resistencia (correr), emotes, cosméticos y progresión permanente.
- Animación de caminar de los infectados.

## 8. Riesgos de esta semana

| Riesgo | Qué hacer |
|---|---|
| Un mapa generado deja zonas sin camino o con puntos dentro de una pared | Las pruebas de camino con 10 semillas desde el día 2. Si falla, el mapa se rehace con otra semilla. |
| Muchos infectados con el mapa grande bajan el rendimiento | Medirlo en el día 5 con la prueba de 30 infectados (la de `SelfTest` o la de `StressTest.server.lua`). |
| Desactivar la reaparición automática deja a un jugador sin personaje | Restaurar `CharacterAutoLoads` siempre al terminar la partida, también si hay error; con prueba. |
| Pisarse en Git | Cada uno toca solo sus servicios. Los cambios compartidos (`Remotes`, `Config`, `Items`) se avisan antes. |
| `SelfTest.server.lua` ya es muy largo | Si el archivo pasa de ~1,800 líneas, cada uno pone sus pruebas nuevas en un script propio (`MatchTest.server.lua`, `MapTest.server.lua`). |
| Rojo se cae al cambiar `default.project.json` | Desconectar Rojo en Studio antes de tocar ese archivo. |
