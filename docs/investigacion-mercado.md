# Investigación de mercado: qué juego de Roblox construir

Fecha: 16 de octubre de 2026. Equipo: 2 desarrolladores (Rafael y Axel), Rojo + GitHub + Claude, poco arte 3D, MVP en 2 a 4 semanas.

## Cómo leer este informe

Las cifras vienen de tres niveles de confianza:

- **[Oficial]** Documentación de Roblox o presentaciones de resultados de Roblox.
- **[Prensa]** Medios y análisis que citan a Roblox.
- **[Estimado]** Sitios de terceros que modelan ingresos a partir de visitas. Varían hasta 10 veces entre fuentes. Úsalos solo para el orden de magnitud.

No encontré datos públicos fiables de retención D1/D7/D30 por género, ni de qué porcentaje del ingreso viene de Game Passes frente a Developer Products. Donde falta el dato, lo digo y dejo una hipótesis para medir con nuestro propio juego.

---

## 1. Panorama de la plataforma (lo que cambió en 2026)

| Dato | Valor | Confianza |
|---|---|---|
| Pagos a creadores, últimos 12 meses | ~US$1.7 mil millones | Prensa |
| Crecimiento de pagos DevEx interanual | ~50% | Prensa |
| Creadores en DevEx | +42,000 | Prensa |
| Promedio de los 10 mejores creadores | US$65.7 millones | Prensa |
| Promedio de los 100 mejores | US$10.8 millones | Prensa |
| Promedio de los 1,000 mejores | US$1.4 millones | Prensa |
| **Creador mediano** | **~US$1,500 al año** | Prensa |
| DAU Q2 2026 | ~123 millones, por debajo del pico de 152 millones en Q3 2025 | Prensa |
| Bookings Q2 2026 | +8% interanual (antes se esperaba +22 a 26%) | Prensa |
| Pagadores únicos mensuales | 27 millones, bajo el pico de 36.7 millones en Q4 2025 | Oficial |

**Lectura para nosotros:**

1. El dinero está **muy concentrado**. El creador mediano gana poco. Hay que apuntar a un juego que pueda estar en el 1% superior o aceptar que será un proyecto de aprendizaje.
2. En 2026 Roblox exigió **verificación de edad para el chat**. Eso frenó el crecimiento de usuarios y de gasto. Roblox dice que los usuarios mayores de 18 años gastan más de 50% más que los menores. Un juego que atraiga a mayores de 13 o de 18 tiene mejor monetización, pero esos jugadores exigen más calidad.
3. Roblox **desactivó la venta de Game Passes entre experiencias** y señaló que eso afectó la monetización.
4. Una tarifa de DevEx más alta para jugadores adultos verificados en EE. UU. apareció solo en fuentes de baja confianza. No planeen con ella hasta confirmarla en la página oficial de DevEx.

### Tarifa de DevEx y comisión

- Roblox se queda con **30%** de Game Passes y Developer Products. Una compra de 100 Robux deja 70 al creador. [Prensa]
- La tarifa de cambio más repetida es **~US$0.0035 por Robux ganado**. Otra fuente dice US$0.0038. **Hay que confirmar en la página oficial de DevEx** y confirmar también el mínimo de retiro (una fuente dice 30,000 Robux, otra 100,000) y si Perú está entre los países soportados.
- Dato práctico: 1,000,000 Robux de ventas brutas son ~700,000 Robux para el creador, o unos US$2,450 con la tarifa de 0.0035.

---

## 2. Cambio importante: ya no existen los pagos por engagement de Premium

El programa **Engagement-Based Payouts fue reemplazado por Creator Rewards el 24 de julio de 2025**. [Oficial] Nuestro plan no debe contar con el modelo antiguo. Ahora funciona así:

| Recompensa | Cómo se calcula |
|---|---|
| **Daily Engagement** | 5 Robux por cada *Active Spender* que juega 10 o más minutos al día en tu juego, si es uno de los 3 primeros juegos que abre ese día. No requiere inscripción. |
| **Audience Expansion** | 35% de los primeros US$100 en compras de un usuario nuevo o reactivado, durante sus primeros 60 días. Requiere cuenta con ID verificado y que el juego promedie 100 o más DAU en esos 60 días. |
| Retención del pago | Los Robux se acreditan con **60 días de espera**. |

Un *Active Spender* es un usuario que gastó al menos US$9.99 en Robux, Premium o suscripciones UGC en los últimos 60 días.

**Qué significa para el diseño:**

- Importa que los jugadores **gasten en Roblox en general** y que **vuelvan a tu juego cada día durante 10 o más minutos**. Una sesión corta de 3 minutos no cuenta.
- Hay que ser **uno de los primeros 3 juegos del día** de ese usuario. Eso premia los hábitos diarios: recompensas diarias, eventos con horario, cosechas que maduran en horas.
- Audience Expansion premia traer **jugadores nuevos** que compren. Un juego viral con compras tempranas gana más.
- Aviso de integridad: bots, cuentas alternas o referidos falsos pueden hacer que pierdan los pagos o la cuenta.

---

## 3. Top 3 géneros y nichos recomendados

### Qué está funcionando (con salvedades)

- **Idle / farming / coleccionar con RNG:** *Grow a Garden* llegó a ~22 millones de jugadores simultáneos en agosto de 2025 [Prensa]. *Steal a Brainrot* superó ese récord según algunas fuentes [Prensa]. Son juegos de **esperar, coleccionar y robar o competir**, con casi todo el valor en sistemas y UI.
- **Terror cooperativo:** *99 Nights in the Forest* tuvo picos de 14.2 millones [Prensa]. *DOORS* y *Dead Rails* (4 jugadores en un tren, creado por un grupo con +70 títulos) siguen vigentes.
- **Pesca:** una fuente reporta una categoría con +55% interanual [Estimado].
- **Combate:** una fuente lo llama el género de más rápido crecimiento [Estimado].

Los ingresos de cada juego que circulan (Grow a Garden entre US$20M y US$287M, Steal a Brainrot entre US$100M y US$590M) **no son confiables**. Lo que sí es consistente: la gente gasta en **ahorrar tiempo, mejorar la suerte y abrir cajas o huevos aleatorios**.

### Los 3 nichos para nosotros

| # | Nicho | Esfuerzo de arte | Valor en scripts | Riesgo |
|---|---|---|---|---|
| 1 | **Coleccionar con RNG + idle, con un giro social** | Bajo | Muy alto | Mercado saturado de clones |
| 2 | **Roguelite cooperativo por oleadas** (sinergias de ítems) | Bajo a medio | Muy alto | Más difícil de balancear y de probar en equipo |
| 3 | **Cooperativo de supervivencia en vehículo** (tipo Dead Rails) | Medio | Alto | El mapa y los enemigos necesitan más arte |

---

## 4. Matriz de monetización

Lo que sigue es **hipótesis de diseño**. No tengo datos públicos que den precios óptimos. Los precios son puntos de partida para probar con pruebas A/B.

| Producto | Tipo | Precio inicial (Robux) | Cómo encaja en el core loop |
|---|---|---|---|
| Doble velocidad / x2 de ganancias | **Game Pass** | 199 a 399 | Se siente en cada minuto de juego. Es el pase que más se compra. |
| Auto-recolectar / auto-abrir | **Game Pass** | 249 a 499 | Quita fricción al jugador que ya está enganchado. |
| VIP (cosmético y chat) | **Game Pass** | 99 a 199 | Compra emocional, de bajo costo. |
| Paquete de monedas (3 tamaños) | **Developer Product** | 49 / 149 / 399 | Se ofrece cuando al jugador le falta poco para algo. |
| Poción de suerte temporal | **Developer Product** | 25 a 99 | Duración 10 a 30 minutos. Es consumible, se repite. |
| **Suerte de servidor** (beneficia a todos) | **Developer Product** | 99 a 299 | El comprador aparece en pantalla como benefactor. Es clipable y social. |
| Salto de espera / abrir ya | **Developer Product** | 19 a 99 | Se vende justo cuando hay un temporizador. |
| Revivir (en modos cooperativos) | **Developer Product** | 29 a 99 | Se ofrece al morir, con cuenta regresiva de 10 segundos. |
| Suscripción mensual de beneficios | Suscripción | 199 a 399 al mes | Retiene a los que ya gastan. |
| Servidor privado | Servidor VIP | 150 a 400 al mes | Ingreso extra de comunidades. |

**Reglas para no matar la retención del jugador gratis:**

1. El jugador gratis debe poder **avanzar y divertirse** sin pagar. Lo pagado acelera, no desbloquea lo básico.
2. **No vender ventaja injusta** en modos competitivos o de robo entre jugadores.
3. Mostrar la primera oferta **después de 5 a 10 minutos de juego**, no al entrar.
4. **Mostrar las probabilidades** de cualquier objeto aleatorio comprado con Robux. Roblox lo exige. Revisen las políticas vigentes antes de lanzar y tengan en cuenta que algunos países restringen las cajas de botín.
5. Ofrecer paquetes **por tiempo limitado** y recompensas diarias: apoyan el hábito de volver cada día que premia Creator Rewards.
6. El público de Roblox incluye muchos menores. Diseñar las ofertas sin presión excesiva ni trucos engañosos, y con confirmación clara de compra.

---

## 5. Tres conceptos de MVP

### Concepto A: "Laboratorio de Mutaciones" (coleccionar con RNG y eventos de servidor)

- **Core loop:**
  - *30 segundos:* tocar para cultivar o fusionar, ver un número subir, abrir un huevo.
  - *5 minutos:* mejorar el laboratorio, elegir qué mutación perseguir, vender o conservar.
  - *1 hora:* completar una colección, llegar a un nuevo "ascenso" (reinicio con bonificación permanente), pelear por un evento global.
- **Giro viral:** **eventos de servidor** (tormenta mutante, lluvia de suerte) que cualquier jugador puede comprar o activar para todos. Todos ven una animación y un cartel con el nombre del jugador que lo activó. Es fácil de grabar para TikTok o Shorts: "alguien activó suerte x10 en el servidor y me salió esto".
- **Arquitectura en Rojo (sistemas a programar con Claude):**
  - `DataService`: guardado con DataStore, reintentos, sesiones bloqueadas.
  - `RngService`: tablas de probabilidad con pesos, suerte y garantía (*pity*).
  - `MutationService`: reglas de combinación de mutaciones.
  - `EventService`: eventos programados con reloj de servidor.
  - `EconomyService`: monedas, costos con curva exponencial, ascensos.
  - `ShopService`: Game Passes y Developer Products con `ProcessReceipt` seguro.
  - `UiController`: interfaz hecha por código (inventario, tienda, índice).
  - `Remotes` con validación de todo lo que envía el cliente.
- **Arte necesario:** muy poco (íconos, un laboratorio simple, partículas).
- **Tiempo de MVP para 2 personas:** **2 a 3 semanas**.
- **Riesgo:** hay muchos clones. Sin el giro social será uno más.

### Concepto B: "Último Refugio" (roguelite cooperativo por oleadas)

- **Core loop:**
  - *30 segundos:* esquivar, disparar o atacar con ataque automático, recoger experiencia.
  - *5 minutos:* elegir 1 de 3 mejoras, acumular sinergias entre objetos.
  - *1 hora:* completar una run de 15 a 20 minutos, desbloquear personajes y objetos permanentes.
- **Giro viral:** **combinaciones absurdas de objetos** que rompen el juego (todos los jugadores combinan sus mejoras en una sola). Se graban los momentos de "build roto".
- **Arquitectura en Rojo:**
  - Máquina de estados de la partida (lobby, oleada, mejora, fin).
  - Generador de oleadas con presupuesto de dificultad.
  - Sistema de ítems con etiquetas y reglas de sinergia basadas en datos.
  - `Matchmaking` y salas con `TeleportService` y servidores reservados.
  - Sistema de enemigos simples con pathfinding barato.
  - Progresión permanente y tienda.
- **Arte necesario:** bajo a medio (formas simples y efectos).
- **Tiempo de MVP:** **3 a 4 semanas**.
- **Riesgo:** balancear sinergias lleva muchas pruebas, y sin jugadores de prueba el equilibrio sale mal.

### Concepto C: "Vagón 9" (supervivencia cooperativa en un vehículo en movimiento)

- **Core loop:**
  - *30 segundos:* defender el vehículo, recoger recursos del camino.
  - *5 minutos:* parar en una estación, comprar mejoras, reparar.
  - *1 hora:* completar el trayecto completo y desbloquear rutas más difíciles.
- **Giro viral:** el **caos cooperativo** (un jugador sin querer rompe el vagón). Muy clipable para streamers.
- **Arquitectura en Rojo:**
  - Generación procedural del recorrido por segmentos modulares.
  - Sistema de enemigos y oleadas por distancia.
  - Física del vehículo y objetos transportables.
  - Inventario y armas con datos.
  - Reaparición y revivir (Developer Product).
- **Arte necesario:** medio (segmentos del camino, enemigos, armas). Es el punto débil del equipo.
- **Tiempo de MVP:** **4 a 6 semanas**.
- **Riesgo:** supera la ventana de 2 a 4 semanas y depende más de arte.

---

## 6. Matriz de esfuerzo contra retorno

Puntaje de 1 (malo) a 5 (bueno). "Esfuerzo" mayor puntaje significa menos esfuerzo.

| Criterio | A: Laboratorio | B: Roguelite | C: Vagón |
|---|---|---|---|
| Esfuerzo (menos es mejor) | **5** | 3 | 2 |
| Encaja con "solo scripts" | **5** | 4 | 3 |
| Cabe en 2 a 4 semanas | **5** | 3 | 1 |
| Potencial de ingresos con compras repetibles | **5** | 3 | 3 |
| Potencial viral | 3 | **4** | **4** |
| Saturación del mercado (menos es mejor) | 2 | **4** | 3 |
| Afinidad con hábito diario (Creator Rewards) | **5** | 3 | 2 |
| **Total** | **30** | 24 | 18 |

---

## 7. Recomendación final

**Construir el Concepto A, "Laboratorio de Mutaciones", como primer juego.**

**Por qué:**

1. Es el que mejor cabe en 2 a 4 semanas con poco arte. Casi todo el valor está en Luau, que es lo que mejor hacemos.
2. Su monetización natural (suerte, ahorro de tiempo, paquetes, eventos de servidor) coincide con lo que los juegos más grandes de 2025 y 2026 venden.
3. Su estructura de **volver cada día** encaja con Creator Rewards, que premia sesiones de 10 minutos y jugadores que gastan.
4. Los sistemas (guardado, RNG, economía, tienda) se **reutilizan** para el siguiente juego, incluido el Concepto B.

**Riesgo principal y cómo cubrirlo:** hay muchos clones. El giro de **eventos de servidor comprables y visibles** tiene que estar en el MVP desde la primera semana, no como mejora posterior.

**Condición para decidir si seguimos:** publicar el MVP, llevar 100 a 300 jugadores de prueba (amigos, comunidades, anuncios pequeños) y medir:

- Retención al día siguiente (D1). Una referencia común de la industria es 20 a 30% como piso aceptable, pero **no es un dato verificado de Roblox**.
- Minutos por sesión (¿pasan de 10?).
- Porcentaje de jugadores que compran algo.

Si D1 queda por debajo de ~15%, se corrige el core loop antes de gastar en anuncios. Si es mayor a 25%, se sigue invirtiendo.

**Siguiente paso técnico:** crear en el repo la estructura de Rojo y los servicios base (`DataService`, `RngService`, `EconomyService`, `ShopService`) en las ramas `dev-rafael` y `dev-axel`. Propuesta de reparto: Rafael en datos, economía y tienda; Axel en RNG, mutaciones, eventos e interfaz.

---

## Fuentes consultadas

- Roblox, Creator Rewards: https://create.roblox.com/docs/creator-rewards
- Roblox, aviso de cierre de Engagement-Based Payouts: https://create.roblox.com/docs/production/monetization/engagement-based-payouts
- Roblox, resultados Q2 2026 (SEC): https://www.sec.gov/Archives/edgar/data/0001315098/000162828026051059/ex991-robloxq22026earnin.htm
- Roblox, carta a accionistas Q2 2026: https://s27.q4cdn.com/984876518/files/doc_financials/2026/q2/Roblox-Q2-2026-Earnings-Shareholder-Letter.pdf
- Dexerto, ingresos de los creadores: https://www.dexerto.com/roblox/robloxs-top-creators-average-65-7-million-a-year-but-most-make-far-less-3408675/
- Análisis de Steal a Brainrot: https://freesystems.substack.com/p/the-algorithm-behind-steal-a-brainrot
- Grow a Garden (Wikipedia): https://en.wikipedia.org/wiki/Grow_a_Garden
- Nasdaq, estrategia de seguridad y usuarios: https://www.nasdaq.com/articles/can-robloxs-safety-first-strategy-restore-user-momentum
- RoWatcher, cuentas de DevEx: https://rowatcher.com/news/roblox-devex-math-what-you-actually-take-home-in-2026
- Rankings de juegos 2026 (terceros): https://rowatcher.com/news/top-10-roblox-games-by-players-march-2026-data-breakdown, https://studiokrew.com/blog/top-roblox-games-may-2026/, https://kitsblox.com/blog/popular-roblox-game-genres-2026
- Estimaciones de ingresos (terceros, baja confianza): https://profitable.app/roblox/games/grow-a-garden
