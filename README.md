# Foco

> No te ayuda a registrar tareas. Te ayuda a **decidir qué hacer cuando estás abrumada**.

App en Flutter (web, escritorio y móvil) que, ante "tengo diez cosas pendientes, ¿cuál hago
ahora?", responde con una recomendación clara. El corazón es un **motor de priorización por
reglas** (sin IA): determinista, explicable y sin costo.

## Cómo funciona

Cada tarea lleva tres ejes (de 1 a 5) además de fecha, tiempo estimado y categoría:

- **Impacto**: cuánto mueve la aguja (Mínimo … Muy alto).
- **Urgencia**: qué tan pronto debe hacerse (Puede esperar … Muy urgente).
- **Ansiedad**: cuánto te bloquea emocionalmente (Tranquila … Me está bloqueando).

Puntaje: `(Urgencia + Impacto) × 2 + PresiónDeFecha − TiempoDisponible`, que se traduce en
una prioridad **Baja / Media / Alta / Muy alta** visible al crear la tarea. La ansiedad
desempata: ante puntajes similares, primero lo que más te bloquea.

Otros componentes:

- **Crear tareas por voz**: dices «Terminar Geotón para el viernes, es urgente, me toma dos
  horas» y Foco entiende título, fecha, duración, categoría y los tres ejes. El dictado lo hace
  el reconocedor del sistema/navegador (`speech_to_text`); la interpretación es por reglas
  propias en español (`lib/core/voice_task_parser.dart`), sin IA.
- **Cuentas con JWT**: registro e inicio de sesión contra un backend Node + MySQL. También se
  puede usar **sin cuenta** (todo queda en el dispositivo).
- **Sistema anti-sobrecarga**: máximo 3 focos activos a la vez.
- **Dependencias**: si una tarea depende de otra sin cerrar, queda *bloqueada*.
- **Mascota emocional** y **logros** que premian el *cierre*, no la cantidad.
- **Planificador**: ubica tus focos activos en los huecos libres del calendario.

## Ejecutar sin backend (modo local)

```bash
flutter pub get
flutter run            # 100% offline, sin cuenta
```

## Ejecutar con cuentas (backend + MySQL)

Requisitos: Node 20+ y MySQL/MariaDB (por ejemplo XAMPP).

1. Arranca MySQL (en XAMPP: botón *Start* de MySQL, o
   `C:\xampp\mysql\bin\mysqld.exe --defaults-file=C:\xampp\mysql\bin\my.ini --standalone`).
2. Configura y arranca la API:

```bash
cd backend
npm install
cp .env.example .env      # pon un JWT_SECRET largo (≥ 32 caracteres) y tus datos de MySQL
npm run db:init           # crea la base "foco" y sus tablas
npm start                 # http://localhost:3000
```

3. Ejecuta la app apuntando a la API:

```bash
flutter run -d chrome --dart-define=API_URL=http://localhost:3000
```

En VS Code/Cursor está la configuración de lanzamiento «Foco (con cuentas · backend local)».

La primera cuenta que inicia sesión en un dispositivo hereda las tareas que se hubieran creado
sin cuenta. Cada cambio se guarda primero en local y luego se envía; si no hay red, se reenvía
al recuperarla.

## Tests

```bash
flutter analyze
flutter test                         # motor, voz, planificador, repositorio, diseño del editor
cd backend && npm test               # API contra la base foco_test

# Extremo a extremo (con la API arrancada):
flutter test test/backend_e2e_test.dart --dart-define=E2E_API_URL=http://localhost:3000
```

## Arquitectura

```
lib/
  config/app_config.dart        # API_URL y Google por --dart-define
  models/                       # Task, Project, FocoUser, Achievement, CalendarEvent, planner
  core/                         # priority_engine, voice_task_parser, pet_state, block_planner
  data/                         # FocoRepository + LocalRepository + ApiRepository + ApiClient
  services/                     # VoiceService, CalendarService (Google + muestra)
  state/                        # AuthState (sesión JWT) y AppState (tareas)
  ui/                           # acceso, inicio, editor, hoja de voz, planificador, logros
backend/
  db/schema.sql                 # tablas MySQL
  src/                          # Express: auth (registro/login JWT) y sync
  test/                         # tests de la API
```

La app trabaja siempre contra la interfaz `FocoRepository`: `LocalRepository`
(shared_preferences) sin cuenta, o `ApiRepository` con sesión. El motor de prioridad y la
mascota **nunca** se persisten: son derivados.

### API

| Método | Ruta | Descripción |
| --- | --- | --- |
| POST | `/api/auth/register` | `{nombre, email, password}` → `{token, user}` |
| POST | `/api/auth/login` | `{email, password}` → `{token, user}` |
| GET | `/api/auth/me` | Usuario de la sesión |
| DELETE | `/api/auth/me` | `{password}` → elimina la cuenta y todos sus datos |
| GET | `/api/sync` | Tareas, proyectos y logros del usuario |
| PUT | `/api/sync/tasks` · `/projects` · `/achievements` | Reemplaza el conjunto (logros: acumulativo) |

Contraseñas con bcrypt, JWT HS256 con caducidad de 7 días y límite de intentos en el acceso.

## Despliegue (servidor)

Publicado en `http://2.25.102.3/gestor-tareas/`, todo dentro de `/var/www/gestor-tareas`:

- `app/`: clon de `main` (la API corre con PM2 como `gestor-tareas-api`, puerto 3020 local).
- `web/`: la web compilada, que GitHub Actions (`.github/workflows/web.yml`) publica en la rama `web`.

Cada push a `main` se publica solo: Actions compila la web y el temporizador
`gestor-tareas-actualizar.timer` revisa GitHub cada minuto, descarga la web y reinicia la API
si cambió (`deploy/actualizar.sh`). Basta con recargar la página. Registro:
`journalctl -u gestor-tareas-actualizar -n 50`.

## Voz por plataforma

- **Web**: Chrome y Edge (usan el servicio de voz del navegador, requiere internet).
  Firefox no lo soporta; ahí se puede escribir la frase en la misma hoja.
- **Android/iOS**: permisos de micrófono ya declarados en `AndroidManifest.xml` e `Info.plist`.

## Activar Google Calendar

Foco recibe un **access token ya válido** (scope `.../auth/calendar`):

```dart
final client = GoogleAuth.clientDesdeAccessToken(accessToken);
final cal = GoogleCalendarService(client, email: usuarioEmail);
PlannerScreen(service: cal);
```

Sin calendario conectado, el planificador reparte tus focos en tu jornada laboral
(`AppConfig`, 9:00–18:00) de los próximos 7 días. Foco no incluye datos de ejemplo:
todo lo que ves son las tareas que creas tú.

## Estado

- ✅ Núcleo offline: priorización (1–5), anti-sobrecarga, mascota, logros.
- ✅ Backend Node + MySQL con registro/login JWT y sincronización.
- ✅ Creación de tareas por voz en español.
- ✅ Editor responsive (escritorio centrado / móvil en una columna) con prioridad en vivo.
- ✅ Planificador de bloques + servicio de calendario.
- ⏳ Pendiente: recuperar contraseña, sync incremental entre varios dispositivos a la vez,
  login con Google y UI de proyectos.
