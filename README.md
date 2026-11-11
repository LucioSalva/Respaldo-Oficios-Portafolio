# Respaldo de Oficios

Sistema web interno para el registro, seguimiento y archivo de oficios institucionales de una Tesorería Municipal, con módulos complementarios de personal, vacaciones e incidencias. Desarrollado en **PHP 8.2 puro + PostgreSQL** sobre Apache.

> **Versión de portafolio:** se removieron datos, configuraciones y recursos institucionales. El sistema original está en producción en una dependencia municipal (Tesorería Municipal del H. Ayuntamiento de Ecatepec de Morelos, Estado de México).

---

## Problema que resuelve

El control de oficios se llevaba en hojas de Excel compartidas: folios capturados a mano (con variantes y duplicados), nombres de dependencias escritos de ~100 formas distintas, sin historial de quién movió qué ni respaldo de los PDF de acuse y respuesta. Lo mismo ocurría con el control de vacaciones e incidencias del personal.

El sistema centraliza esa información con:

- **Folios generados por la base de datos** de forma atómica, sin duplicados ni huecos por concurrencia.
- **Trazabilidad completa**: cada cambio de estado queda como movimiento con usuario y fecha, y las acciones relevantes quedan en una bitácora de auditoría.
- **Evidencias PDF** (oficio recibido, acuse, respuesta) almacenadas fuera del webroot.
- **Migración de los Excel históricos** a través de tablas de *staging* con revisión de errores antes de consolidar.

---

## Módulos

| Módulo | Qué hace |
|---|---|
| **Oficios** | Alta, edición, consulta con filtros y paginación. Tres tipos: **EXTERNO** (recibido de otra dependencia; folio 1–9999 por año), **INTERNO** (áreas internas de la Tesorería; 10000–19999) y **de CONOCIMIENTO** (solo para enterarse, no requiere respuesta; 20000+). Preview del folio en tiempo real y soporte de folio *pendiente*. |
| **Folios y trazabilidad** | Folio de tesorería `TM/MUN/STIyC/XXXX/AAAA` como columna generada en PostgreSQL; reserva del siguiente número con `pg_advisory_xact_lock`; historial de movimientos de estado por oficio. |
| **Evidencias** | Carga de PDF por oficio con tipo de evidencia, descarga y visualización inline servidas por controlador. |
| **Personal** | Catálogo operativo de trabajadores (sindicalizados / confianza), separado de los usuarios de login. |
| **Vacaciones** | Movimientos de vacaciones por empleado y periodo, saldos derivados (asignados / usados / restantes), detalle por empleado, búsqueda y reporte de **inconsistencias**. |
| **Incidencias** | Omisiones de entrada/salida, faltas, retardos, permisos, incapacidades, comisiones, etc., con flujo de justificación y cancelación. |
| **Catálogos** | Dependencias, áreas internas, estados de oficio y tipos de evidencia (alta, edición, activar/desactivar). |
| **Usuarios** | CRUD con roles **GOD / Admin / User** y salvaguarda que impide dejar el sistema sin un GOD activo. |
| **Importación** | Subida del Excel y tablero del estado de las tablas `import_*_raw` y sus errores. |
| **Dashboard** | Estadísticas generales y últimos oficios registrados. |

---

## Arquitectura

```
Navegador ──► Apache (DocumentRoot = public/)
                 │
                 └─► public/index.php  (front controller + router)
                         │
                         ├─ app/core/        Router, Controller, Auth, Session, Database (PDO),
                         │                   Validator, FolioService, VacacionesService, ErrorHandler
                         ├─ app/controllers/ Un controlador por módulo
                         ├─ app/models/      Consultas de Personal, Vacaciones, Incidencias
                         ├─ app/helpers/     url, auth, csrf, upload
                         └─ app/views/       Plantillas PHP + layouts (Bootstrap 5)
                                 │
                                 ▼
                           PostgreSQL 17
```

- **PHP puro, sin framework**: router propio con patrones `/:id`, controladores y vistas PHP. Elegido por simplicidad de despliegue y mantenimiento en un servidor institucional sin salida a internet.
- **`app/` fuera del webroot**: Apache solo sirve `public/`. Un `.htaccess` en la raíz bloquea carpetas internas por si el DocumentRoot se configurara mal, y `public/.htaccess` niega cualquier `.php` que no sea `index.php`.
- **Soporte de subcarpeta**: la app puede servirse en la raíz del host o bajo un `Alias` (p. ej. `/oficios`) con `APP_BASE_PATH`; el router recorta el prefijo y los helpers `url_path()` / `asset_url()` lo agregan.
- **Lógica crítica en la base de datos**: columnas generadas, `CHECK` de consistencia por tipo de oficio (p. ej. EXTERNO ⇒ dependencia obligatoria, INTERNO ⇒ área interna obligatoria), índices `UNIQUE` parciales, triggers de `updated_at` y vistas de reporte.
- **Migraciones SQL numeradas** (`sql/01..12`) idempotentes y transaccionales.

---

## Decisiones de seguridad

- **PDO con *prepared statements*** en todas las consultas.
- **CSRF** en todos los formularios POST: token de 32 bytes (`random_bytes`) en sesión, comparado con `hash_equals`.
- **Sesiones endurecidas**: cookie `HttpOnly` y `SameSite=Strict`, `session.use_strict_mode`, `session_regenerate_id()` al iniciar sesión y destrucción completa de sesión y cookie al salir.
- **Rate-limit de login**: máximo 5 intentos fallidos por usuario/correo o por IP en una ventana de 10 minutos (tabla `login_intentos`).
- **Contraseñas** con `password_hash` (bcrypt) y política de complejidad (`Validator::passwordComplex`). El seed **no** crea usuarios ni versiona hashes.
- **Uploads seguros**: MIME real con `finfo` (nunca `$_FILES['type']`), nombre físico aleatorio, archivos fuera del webroot y entrega por controlador con control de acceso y protección contra *path traversal*.
- **Roles** verificados en cada acción (`Auth::requireRole`).
- **Bitácora de auditoría** (usuario, acción, tabla, IP, user-agent, datos JSON).
- **Manejo global de errores**: en producción se muestra una página 500 con ID de incidente; el detalle va al log. `APP_DEBUG` se fuerza a `false` cuando `APP_ENV=production`.
- **Cabeceras de seguridad** (`X-Frame-Options`, `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`) y bloqueo de extensiones sensibles (`.env`, `.sql`, `.log`, …) vía Apache.
- **Secretos solo en variables de entorno** (`.env` no versionado; ver `.env.example`).

---

## Stack

- PHP 8.2 (PDO, pdo_pgsql, fileinfo)
- PostgreSQL 17
- Apache 2.4 con `mod_rewrite` y `mod_headers`
- Bootstrap 5.3, Font Awesome, JavaScript vanilla, SCSS
- Docker (opcional, solo para la app PHP)

---

## Estructura

```
.
├── app/
│   ├── config/        # paths, config (lee .env), sesión
│   ├── core/          # Router, Auth, Session, Database, Validator, FolioService, VacacionesService, ErrorHandler
│   ├── controllers/   # Oficio, Movimiento, Evidencia, Personal, Vacaciones, Incidencia, Catalogo, Usuario, Import, Dashboard, Auth
│   ├── models/        # PersonalModel, VacacionesModel, IncidenciaModel
│   ├── helpers/       # url, auth, csrf, upload
│   └── views/         # vistas por módulo + layouts y páginas de error
├── public/            # ÚNICA carpeta servida por Apache
│   ├── index.php      # front controller y tabla de rutas
│   ├── .htaccess
│   └── assets/        # css, scss, js
├── sql/               # migraciones 01..12 + 99_demo_seed.sql (datos ficticios)
├── tests/             # scripts CLI de verificación (sin dependencias)
├── tools/             # smoke test de layout y diagnóstico de uploads
├── deploy/            # ejemplo de configuración Apache bajo subcarpeta
├── storage/logs/
├── uploads/           # evidencias (fuera del webroot)
├── Dockerfile
└── docker-compose.yml
```

---

## Cómo levantarlo localmente

### Requisitos

- PHP 8.2+ con `pdo_pgsql` y `fileinfo`
- PostgreSQL 15+ (probado con 17)
- Apache con `mod_rewrite` (o el servidor embebido de PHP para pruebas)

### 1. Variables de entorno

```bash
cp .env.example .env
# Editar DB_* y APP_SECRET (todo lo marcado como CHANGE_ME)
```

### 2. Base de datos

```bash
createdb respaldooficios
for f in sql/*.sql; do psql -d respaldooficios -v ON_ERROR_STOP=1 -f "$f"; done
```

Esto aplica el esquema, los catálogos y `99_demo_seed.sql` (personal, oficios, incidencias y vacaciones **ficticios**).

### 3. Crear el primer usuario (GOD)

```bash
php -r "echo password_hash('TuPassword123', PASSWORD_BCRYPT, ['cost'=>12]), PHP_EOL;"

psql -d respaldooficios -c "INSERT INTO usuarios (nombre, username, email, password_hash, rol_id, activo)
VALUES ('Administrador Demo', 'demo', 'demo@ejemplo.com', '<HASH_GENERADO>', 1, TRUE);"
```

### 4. Servir la aplicación

**Opción A — servidor embebido de PHP (rápido, solo desarrollo):**

```bash
php -S localhost:8090 -t public
```

**Opción B — Apache:** apuntar el `DocumentRoot` (o un `Alias`) a `public/` con `AllowOverride All`. Para servir bajo subcarpeta ver `deploy/apache-subpath.conf.example`.

**Opción C — Docker** (contenedor PHP + Apache; PostgreSQL corre en el host):

```bash
docker compose up --build -d
```

Abrir `http://localhost:8090` e iniciar sesión con el usuario creado.

### Pruebas

```bash
php tests/test_folio_formatear.php   # formato de folio (sin BD)
php tests/test_csrf_token.php        # mecánica CSRF (sin BD)
php tools/smoke_layout.php           # rutas, constantes, helpers y router (sin BD)
php tests/test_folio_unique.php      # requiere BD
php tests/test_ultimo_god.php        # requiere BD
```

---

## Nota sobre esta versión

- Se eliminaron los archivos Excel/CSV de origen, respaldos de base de datos, paquetes de despliegue, scripts de importación acoplados a los archivos institucionales y scripts de despliegue con datos del servidor.
- Las migraciones SQL conservan únicamente esquema y catálogos; los datos de demostración son inventados.
- El prefijo de folio se generalizó a `TM/MUN/STIyC`.

---

## English summary

**Respaldo de Oficios** is an internal web application built for a Mexican municipal Treasury office to replace spreadsheet-based tracking of official correspondence ("oficios"). It provides atomic, database-generated document numbering (PostgreSQL generated columns + `pg_advisory_xact_lock`), full status traceability and audit logging, secure PDF evidence storage outside the webroot, and HR-related modules for staff, vacation balances and attendance incidents. It is written in plain PHP 8.2 (no framework) with a custom router, PDO prepared statements, CSRF protection, hardened sessions, login rate-limiting and role-based access, backed by PostgreSQL with idempotent numbered migrations.

*Portfolio version: institutional data, configuration and assets have been removed. The original system is in production at a municipal government office.*
