# Diseño del MVP: Last Refuge

Nombre del juego: **Last Refuge** (en español, *Último Refugio*). Supervivencia cooperativa postapocalíptica.
Nota: existe un juego móvil llamado *Last Shelter: Survival*; por eso usamos *Refuge* y no *Shelter*. Falta buscar el nombre en Roblox para confirmar que está libre.
Estado: borrador v1, 16 de octubre de 2026. Autores: Rafael y Axel, con apoyo de Claude.

## 1. Visión en una frase

Tres o cuatro supervivientes aparecen sin nada en un mundo en ruinas. Tienen 30 minutos para saquear, sobrevivir a las oleadas de infectados y encontrar el búnker. Si alguien muere, pierde todo lo que llevaba. Tono de referencia: **Project Zomboid** (escasez, ruido, decisiones con consecuencias), pero en partidas cortas y cooperativas.

## 2. Decisiones ya tomadas

| Tema | Decisión |
|---|---|
| Duración de la partida | Máximo 30 minutos |
| Muerte | Se pierde todo el inventario |
| Combate | Arma de fuego, cuchillo y bate. Los infectados hay que derrotarlos para cerrar cada oleada |
| Sigilo | Se puede evitar la línea de visión de los infectados, pero no se puede saltar la oleada |
| Grupo | 3 a 4 jugadores |
| Estructura | Lobby, sala de espera por grupo, y salas generales para que se conecte gente nueva |
| Tono | Project Zomboid: escasez, ruido, gestión de recursos |
| Levantar caído | Una sola vez por jugador y por partida. Si vuelve a caer, muere |
| Progresión permanente | Ligera: estadísticas y cosméticos, sin ventajas de poder |
| Cambiar ítems | Ambos: pasar objetos entre jugadores y fabricar con materiales |
| Inicio de partida | Con 2 jugadores ya se puede empezar (la sala admite hasta 4) |
| Cámara | Tercera persona estándar de Roblox, con cámara sobre el hombro al apuntar |

## 3. Pilares de diseño

1. **Escasez.** Nunca hay suficiente munición, comida o espacio. Cada decisión cuesta algo.
2. **El ruido cuenta.** Disparar atrae infectados. El cuchillo y el bate son silenciosos o casi. Esto es lo que hace distinto al juego.
3. **Cooperación obligatoria.** Con 4 jugadores es mucho más fácil. Repartir recursos y cubrirse es parte del juego.
4. **Partidas cortas y rejugables.** Mapa distinto cada vez, pocas piezas de arte reutilizadas.
5. **Todo lo importante está en scripts.** Se minimiza el arte 3D hecho a mano.

## 4. Estructura de una partida (30 minutos)

| Minuto | Fase | Qué pasa |
|---|---|---|
| 0:00 | Aparición | Cada jugador empieza casi sin nada: una linterna y un objeto al azar. Mapa con zonas por explorar. |
| 0:00 a 8:00 | Saqueo 1 | Explorar casas y tiendas, recoger munición, comida, vendas, materiales. Algunos infectados dispersos. |
| 8:00 | **Oleada 1** | Sirena. Los infectados llegan desde varios puntos. Hay que defender una zona o resistir. |
| 10:00 a 17:00 | Saqueo 2 | Zonas más peligrosas con mejor botín. Se empieza a encontrar las **piezas de acceso al búnker** (ver sección 7). |
| 17:00 | **Oleada 2** | Más infectados, aparecen tipos especiales. |
| 19:00 a 25:00 | Saqueo 3 | Llegar a la zona del búnker con las piezas. |
| 25:00 | **Oleada final** | Defender la puerta del búnker mientras se abre (cuenta regresiva de 90 segundos). |
| 27:00 a 30:00 | **Escape** | Quienes llegan adentro ganan. |

Si el tiempo termina o todos mueren, se pierde la partida y se vuelve al lobby.

## 5. Sistemas del juego

### 5.1 Supervivencia del jugador
- **Vida**, **hambre** y **resistencia** (para correr). Sin sed ni temperatura en el MVP.
- La comida restaura hambre. Con hambre alta se pierde vida lentamente.
- Vendas y botiquines curan. Una herida grave sangra hasta que se venda.

### 5.2 Inventario
- **Espacio limitado** por cuadrículas o por peso (a decidir, lo más simple es por número de ranuras).
- Mochila mejora el espacio (cosmético y de progreso de partida).
- **Soltar y pasar objetos** entre jugadores del grupo. Esto es el "cambiar municiones, comida e ítems" de la idea original.
- **Fabricación:** 5 a 8 recetas simples en el MVP (por ejemplo venda con tela, trampa de ruido con latas, cargador con munición suelta). Más recetas pueden venir en actualizaciones.
- Al morir, el cuerpo suelta lo que llevaba. **Otro jugador puede recoger el botín** si llega a tiempo. Esto cumple "pierde todo" sin que sea injusto para el equipo.

### 5.3 Botín
- Cada edificio tiene puntos de botín con una **tabla de probabilidades** según el tipo (casa, tienda, comisaría, almacén).
- Los puntos se rellenan al comenzar la partida (no reaparecen).
- La rareza sube en zonas peligrosas.

### 5.4 Armas
| Arma | Daño | Ruido | Límite |
|---|---|---|---|
| Cuchillo | Bajo | Casi nulo | Alcance corto |
| Bate | Medio | Medio | Se desgasta |
| Pistola | Alto | **Muy alto, atrae a todos los cercanos** | Munición escasa, recarga |

- Impacto de la pistola: rayo desde el servidor (*raycast*), el cliente muestra el disparo al instante y el servidor confirma.
- Cuerpo a cuerpo: golpe con tiempo de recuperación y área frente al jugador.
- Todo el daño se calcula **en el servidor**. El cliente nunca decide si un golpe acierta.

### 5.5 Infectados e inteligencia artificial
Máquina de estados: `Inactivo → Deambular → Investigar → Perseguir → Atacar`.

- **Visión:** un cono frontal con distancia máxima. Si el jugador está dentro del cono y no hay pared en medio (raycast), lo detectan.
- **Oído:** cada acción genera un **evento de ruido** con un radio (pistola grande, bate medio, pasos al correr pequeño, agacharse casi nulo). Los infectados dentro del radio pasan a `Investigar` hacia el origen del ruido.
- **Esconderse:** salir del cono de visión y agacharse reduce la detección. Los infectados que pierden al jugador vuelven a `Investigar` el último punto conocido y luego a `Deambular`.
- Tipos para el MVP: **caminante** (lento, común), **corredor** (rápido, débil), **bruto** (lento, mucha vida; aparece desde la oleada 2).
- Límite de infectados activos a la vez (por ejemplo 40 a 60) para no ahogar el servidor. Los lejanos se mantienen "dormidos".

### 5.6 Oleadas
- Controladas por el servidor con un **presupuesto de dificultad** que crece con cada oleada y con el número de jugadores.
- Los infectados aparecen en **puntos de aparición** fuera de la vista de los jugadores y avanzan hacia el ruido o la zona de defensa.
- Una oleada termina cuando se derrotan todos los infectados de esa oleada (como pidieron: no se puede saltar).

### 5.7 El búnker
- Sin llegar a la zona del búnker no se gana.
- **Para abrir la puerta** hace falta reunir **3 piezas de acceso** (por ejemplo: tarjeta, código, combustible del generador) repartidas por el mapa. Esto empuja a explorar y a repartirse la tarea.
- Al abrir, se activa la oleada final y la cuenta regresiva de 90 segundos.
- Al terminar: pantalla de victoria con resumen (tiempo, infectados derrotados, quién salvó a quién).

### 5.8 Mapa
- No es un mundo abierto continuo: es un **mapa generado con zonas modulares** (bosque, calle, gasolinera, casas, comisaría, almacén, zona del búnker) ordenadas al azar en una cuadrícula cada partida.
- Unas **10 a 12 piezas** de arte reutilizables. Se pueden usar modelos verificados de la tienda de creadores, **sin scripts**, o armarlos con partes simples.
- Terreno plano con elementos decorativos. La variedad viene del orden y del botín, no de un mapa único gigante.
- La niebla y una iluminación oscura reducen la distancia visible (más tono y menos carga).

### 5.9 Lobby, salas de espera y matchmaking
- **Lobby:** lugar social seguro donde los jugadores ven la tienda, el equipo y los puestos de espera.
- **Salas de espera por grupo:** cada grupo se forma en una sala (3 a 4 jugadores). Cuando se llena, o pasa un tiempo límite con mínimo de 2 jugadores, se teletransporta a un servidor reservado para la partida (`TeleportService:ReserveServer`).
- **Salas generales:** lista de grupos abiertos o botón "unirme a un grupo", para quien no tenga amigos.
- **Grupos privados:** con código o con invitación de amigos.

### 5.10 Progresión fuera de la partida
Dijeron que al morir se pierde todo. Eso aplica al **equipo de la partida**. Recomendamos que haya una progresión **ligera y solo cosmética o de estadísticas**, para que el jugador vuelva:
- Registros (mejor tiempo, partidas ganadas, infectados derrotados).
- Cosméticos y títulos que se desbloquean al ganar.
- **Sin ventajas de poder permanentes**, para mantener el desafío y para no mezclarse con el pago.

Esto es una **decisión abierta** (ver sección 11).

## 6. Monetización

| Producto | Tipo | Precio inicial (Robux) | Notas |
|---|---|---|---|
| Revivir a un compañero caído una vez por partida | Developer Product | 49 a 99 | Se ofrece cuando alguien cae. Un compañero también puede levantarlo gratis con un botiquín. |
| Skins de personaje y de armas | Game Pass o producto | 99 a 499 | No cambian el poder. |
| Mochila inicial con 2 ranuras extra | Game Pass | 199 a 399 | Comodidad, no poder directo. |
| Servidor privado | Servidor VIP | 150 a 400 al mes | Para grupos de amigos. |
| Señal de suministros (un cofre extra al azar al inicio) | Developer Product | 49 a 149 | Es objeto aleatorio comprado con Robux: **hay que mostrar las probabilidades**. |
| Emotes y efectos de victoria | Producto | 49 a 149 | Clipable. |

Reglas: no vender daño ni munición ilimitada, ni nada que haga el juego injusto para quien no paga. Los precios son una hipótesis para validar.

## 7. Arquitectura del código en Rojo

```
src/
├── server/
│   ├── Main.server.lua
│   ├── Services/
│   │   ├── DataService.lua        # guardado de perfil y estadísticas
│   │   ├── LobbyService.lua       # salas de espera y grupos
│   │   ├── MatchmakingService.lua # teleport a servidor reservado
│   │   ├── MatchService.lua         # máquina de estados de la partida
│   │   ├── MapService.lua         # genera el mapa con módulos
│   │   ├── LootService.lua        # tablas de botín y colocación
│   │   ├── InventoryService.lua   # inventario, soltar, pasar objetos
│   │   ├── CombatService.lua      # daño y validación en servidor
│   │   ├── SurvivalService.lua    # vida, hambre, resistencia
│   │   ├── NoiseService.lua       # eventos de ruido
│   │   ├── ZombieService.lua      # IA, spawn, límite activo
│   │   ├── WaveService.lua        # oleadas y presupuesto de dificultad
│   │   ├── BunkerService.lua      # piezas de acceso y final
│   │   └── ShopService.lua        # compras con ProcessReceipt
├── client/
│   ├── Controllers/
│   │   ├── InputController.lua
│   │   ├── WeaponController.lua   # predicción de disparos, efectos
│   │   ├── HudController.lua      # vida, hambre, munición
│   │   ├── InventoryUi.lua
│   │   ├── LobbyUi.lua
│   │   └── StealthFeedback.lua    # indicador de ruido y detección
└── shared/
    ├── Config/                    # armas, botín, infectados, oleadas
    ├── Remotes.lua                # definición central de eventos
    └── Util/
```

Reglas técnicas:
- **El servidor decide todo** (daño, botín, inventario, compras). El cliente solo pide y muestra.
- Los datos de armas, botín y oleadas viven en **archivos de configuración** para ajustar sin tocar la lógica.
- Cada servicio tiene una sola responsabilidad. Así Rafael y Axel casi no se pisan en Git.
- Las compras usan `MarketplaceService.ProcessReceipt` con registro para evitar duplicados.

## 8. Reparto entre Rafael y Axel

| Persona | Responsable de |
|---|---|
| **Rafael** | `DataService`, `LobbyService`, `MatchmakingService`, `MatchService`, `WaveService`, `BunkerService`, `ShopService`, `LobbyUi` |
| **Axel** | `InventoryService`, `LootService`, `CombatService`, `SurvivalService`, `HudController`, `InventoryUi`, `WeaponController` |
| **Compartido** | `ZombieService` y `NoiseService` (empezar juntos, luego repartir), `MapService` |

Cada uno trabaja en su rama (`dev-rafael`, `dev-axel`) y abre un *pull request* a `main` al terminar cada hito.

## 9. Plan de trabajo (5 a 6 semanas)

| Semana | Hito | Resultado jugable |
|---|---|---|
| 1 | Estructura de Rojo, guardado, jugador con vida y hambre, inventario básico, un solo edificio con botín | Se puede recoger y usar objetos |
| 2 | Armas (cuchillo, bate, pistola), infectado básico que persigue y ataca | Se puede pelear contra infectados |
| 3 | Ruido, visión y sigilo, oleada 1, mapa con 4 o 5 módulos | Primer ciclo saqueo y oleada |
| 4 | Lobby, salas de espera, teletransporte a servidor reservado, 3 oleadas, búnker | **Partida completa de principio a fin** |
| 5 | Tienda y monetización, tipos de infectados, balance, pulido de interfaz | MVP con todas las piezas |
| 6 | Pruebas con 10 a 20 personas, corrección de errores, publicación | Lanzamiento cerrado |

Es más largo que la meta original de 2 a 4 semanas. Si necesitan algo en 4 semanas, se recorta a **una oleada, un solo tipo de infectado y sin tienda** para validar el juego antes.

## 10. Riesgos

| Riesgo | Qué hacer |
|---|---|
| Mucho arte para el mapa | Módulos reutilizables y modelos verificados sin scripts. Revisar cualquier modelo de terceros antes de usarlo. |
| Rendimiento con muchos infectados | Límite de activos, IA simple, simular solo cerca de jugadores. |
| El combate se siente mal | Prototipo temprano (semana 2) y pruebas con jugadores reales. |
| Sin progresión permanente se pierde retención | Estadísticas, cosméticos y metas de desbloqueo (ver 5.10). |
| Pérdida total frustra | Botín del caído recuperable por el equipo, y compañero que puede levantar. |
| Contenido para menores | Violencia moderada, sin gore, clasificación de edad correcta en la página del juego. |
| Cajas aleatorias de pago | Mostrar probabilidades y cumplir las reglas de Roblox. |

## 11. Decisiones cerradas y preguntas abiertas

Cerradas el 16 de octubre de 2026: levantar caído una sola vez, progresión ligera, fabricar y pasar objetos, inicio con 2 jugadores, tercera persona, nombre Last Refuge.

Abiertas:

1. Buscar en Roblox que el nombre *Last Refuge* esté libre.
2. Definir el estilo visual (colores, niebla, interfaz) antes de la semana 3.
3. Decidir si los infectados usan el avatar estándar de Roblox con ropa rota o un modelo propio.
