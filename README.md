# Last Refuge

Juego cooperativo de supervivencia postapocalíptica para Roblox (en español, *Último Refugio*). De 2 a 4 jugadores aparecen sin nada, saquean, sobreviven a tres oleadas de infectados y buscan el búnker en una partida de 30 minutos. Si mueres, pierdes lo que llevabas. Tono de referencia: Project Zomboid.

Desarrollado por [@RafaelCly](https://github.com/RafaelCly) y Axel.

## Documentos

- [Diseño del MVP](docs/diseno-mvp.md): qué vamos a construir, sistemas, reparto y plan.
- [Investigación de mercado](docs/investigacion-mercado.md): por qué este juego y cómo monetizarlo.

## Estado

- [x] Idea y diseño del MVP
- [x] Estructura del proyecto con Rojo (esqueletos)
- [ ] Semana 1: guardado, vida y hambre, inventario básico, un edificio con botín
- [ ] Semana 2: armas e infectado básico
- [ ] Semana 3: ruido, sigilo, oleada 1, mapa modular
- [ ] Semana 4: lobby, matchmaking, 3 oleadas y búnker (partida completa)
- [ ] Semana 5: tienda, tipos de infectados y balance
- [ ] Semana 6: pruebas con jugadores y lanzamiento cerrado

## Requisitos

| Herramienta | Para qué |
|---|---|
| [Roblox Studio](https://create.roblox.com) | Editor y pruebas del juego |
| [Git](https://git-scm.com) | Control de versiones |
| [VS Code](https://code.visualstudio.com) | Editor de código |
| [Rojo](https://rojo.space/docs) (CLI y plugin de Studio) | Sincroniza `src/` con Studio |

Al abrir la carpeta en VS Code se recomiendan las extensiones Rojo, Luau LSP y StyLua.

## Cómo empezar

```bash
git clone https://github.com/RafaelCly/Project_Roblox_1.git
cd Project_Roblox_1
git checkout dev-rafael   # Axel: git checkout dev-axel
```

1. Instala Rojo (CLI) y el plugin de Rojo en Roblox Studio. Guía: <https://rojo.space/docs/v7/getting-started/installation/>.
2. En esta carpeta ejecuta:

   ```bash
   rojo serve
   ```

3. Abre un lugar vacío en Studio, pulsa **Connect** en el plugin de Rojo, y los scripts aparecen solos.
4. Pulsa **Play** y revisa la ventana Output: debe aparecer `[Last Refuge] Servidor iniciado`.

Nada de esto se ha probado todavía dentro de Roblox Studio. Si algo falla al conectar, copia el mensaje del Output y revísalo en el equipo.

## Estructura

```
default.project.json        # Configuración de Rojo
src/
├── server/                 # ServerScriptService.Server
│   ├── Main.server.lua     # Carga los servicios (Init y luego Start)
│   └── Services/           # Un servicio por responsabilidad
├── client/                 # StarterPlayerScripts.Client
│   ├── Main.client.lua
│   └── Controllers/        # Entrada, HUD, inventario, lobby
└── shared/                 # ReplicatedStorage.Shared
    ├── Config/             # Armas, infectados, parámetros de partida
    └── Remotes.lua         # Eventos cliente/servidor
docs/                       # Investigación y diseño
```

Reglas del código:

- El **servidor decide todo** (daño, botín, inventario, compras). El cliente solo pide y muestra.
- Los números de balance viven en `src/shared/Config/`, no dentro de la lógica.
- Cada servicio tiene una sola responsabilidad. Así casi no hay conflictos entre ramas.
- El mapa, los modelos y la interfaz visual se trabajan en Studio con *Team Create*. El código vive aquí.

## Reparto

| Persona | Servicios |
|---|---|
| Rafael | `DataService`, `LobbyService`, `MatchmakingService`, `MatchService`, `WaveService`, `BunkerService`, `ShopService`, `LobbyUi` |
| Axel | `InventoryService`, `LootService`, `CombatService`, `SurvivalService`, `HudController`, `InventoryUi`, `WeaponController` |
| Compartido | `ZombieService`, `NoiseService`, `MapService` |

## Flujo de Git

Cada uno trabaja en su rama y se une a `main` con *pull request*:

```bash
git pull
git add .
git commit -m "Describe el cambio"
git push
```

Antes de abrir el *pull request*, el otro revisa el cambio. Nunca se sube código sin haberlo probado en Studio.

## Monetización (plan)

Revivir a un compañero, cosméticos, mochila inicial, servidor privado y señales de suministro. Sin ventajas de poder de pago. Todo objeto aleatorio comprado con Robux muestra sus probabilidades. Detalle en [docs/diseno-mvp.md](docs/diseno-mvp.md).

El reparto de ingresos entre los dos se acuerda por escrito antes de publicar.

## Reglas del proyecto

- No copiar código ni modelos con derechos de autor.
- Los modelos de terceros se revisan antes de usarlos, y se quitan los scripts que traigan.
- Cumplir las [Normas de la comunidad](https://en.help.roblox.com/hc/en-us/articles/203313410) de Roblox.
- No subir claves, tokens ni datos privados al repositorio.

## Licencia

Por definir.
