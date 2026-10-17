# Project Roblox 1

Juego de Roblox desarrollado en equipo. *(Nombre, género y descripción pendientes de definir.)*

## Estado del proyecto

- [ ] Definir idea y tipo de juego
- [ ] Configurar el proyecto con Rojo
- [ ] Primer prototipo jugable
- [ ] Guardado de datos (DataStore)
- [ ] Monetización (Game Passes / Developer Products)
- [ ] Pruebas con amigos
- [ ] Publicación

## Requisitos

| Herramienta | Para qué sirve |
|---|---|
| [Roblox Studio](https://create.roblox.com) | Editor del juego |
| [Git](https://git-scm.com) | Control de versiones |
| [VS Code](https://code.visualstudio.com) | Editor de código |
| [Rojo](https://rojo.space) | Sincroniza el código del repo con Studio |
| [Aftman](https://github.com/LPGhatguy/aftman) o [Rokit](https://github.com/rojo-rbx/rokit) | Instala Rojo y otras herramientas *(opcional)* |

## Cómo empezar

```bash
git clone https://github.com/RafaelCly/Project_Roblox_1.git
cd Project_Roblox_1
```

Una vez exista `default.project.json`:

1. Abre VS Code en esta carpeta e instala la extensión **Rojo**.
2. En Roblox Studio, instala el plugin de Rojo.
3. Ejecuta `rojo serve` y pulsa **Connect** en el plugin de Studio.
4. Edita los scripts en VS Code: se actualizan solos en Studio.

## Estructura prevista

```
Project_Roblox_1/
├── default.project.json   # Configuración de Rojo
├── src/
│   ├── server/            # Scripts del servidor (ServerScriptService)
│   ├── client/            # Scripts del cliente (StarterPlayerScripts)
│   └── shared/            # Módulos compartidos (ReplicatedStorage)
└── README.md
```

## Cómo trabajamos en equipo

- **Código** (scripts): en este repositorio, con Git y Rojo.
- **Mapa, modelos e interfaz**: en Roblox Studio con *Team Create*.
- Cada persona trabaja en su **propia rama** y se une a `main` mediante *pull request*.
- Nunca se hace *push* directo a `main` con código sin probar.

### Flujo básico de Git

```bash
git pull                       # traer lo último
git checkout -b mi-rama        # crear rama propia
# ... trabajar ...
git add .
git commit -m "Describe el cambio"
git push -u origin mi-rama     # luego abrir Pull Request en GitHub
```

## Monetización (plan)

- **Game Passes**: compras únicas (VIP, ventajas permanentes).
- **Developer Products**: compras repetibles (monedas, boosts).
- **Servidores privados**: opcional, con precio mensual en Robux.
- El reparto de ingresos entre los miembros del equipo se acuerda **por escrito** antes de publicar.

## Reglas del proyecto

- No copiar código ni modelos con derechos de autor.
- Cumplir las [Normas de la comunidad](https://en.help.roblox.com/hc/en-us/articles/203313410) de Roblox.
- No subir claves, tokens ni datos privados al repositorio.

## Equipo

- [@RafaelCly](https://github.com/RafaelCly)
- *(añadir a tu amigo)*

## Licencia

Por definir.
