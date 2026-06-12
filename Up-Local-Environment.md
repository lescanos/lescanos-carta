# Levantar el entorno local — Lescano's

Todo lo que necesitás instalar y cada paso para tener el sistema corriendo en tu máquina.

---

## Requisitos previos

Instalá estas herramientas **una sola vez**. Si ya las tenés, verificá las versiones mínimas.

| Herramienta | Versión mínima | Cómo verificar | Cómo instalar |
|---|---|---|---|
| **Node.js** | v18+ | `node --version` | [nodejs.org](https://nodejs.org) → LTS |
| **npm** | v9+ | `npm --version` | Viene con Node.js |
| **Git** | v2.30+ | `git --version` | [git-scm.com](https://git-scm.com) |
| **Docker Desktop** | v4+ | Ícono en la barra de tareas | [docker.com/desktop](https://www.docker.com/products/docker-desktop/) |

> Docker Desktop debe estar **corriendo** (ícono visible en la barra de tareas) antes de arrancar el entorno.

---

## Primera vez — configuración completa

### 1. Clonar el repositorio

```bash
git clone https://github.com/lescanos/lescanos-carta.git
cd lescanos-carta
```

### 2. Instalar dependencias

```bash
npm install
```

### 3. Levantar la base de datos local

Asegurate de que Docker Desktop esté corriendo, luego:

```bash
npx supabase start
```

La primera vez descarga las imágenes de Docker (puede tardar 5-10 minutos según tu conexión). Las siguientes veces arranca en segundos.

Cuando termina, muestra algo como:

```
{
  "API_URL": "http://127.0.0.1:54321",
  "ANON_KEY": "eyJhbGci...",
  "STUDIO_URL": "http://127.0.0.1:54323",
  ...
}
```

### 4. Aplicar el schema y cargar datos de prueba

```bash
npx supabase db reset
```

Esto crea todas las tablas, políticas RLS y carga los usuarios de prueba. Solo necesitás hacerlo **una vez** (o cuando quieras volver al estado inicial limpio).

### 5. Crear el archivo de entorno local

Copiá el ejemplo y completalo con los valores del paso 3:

```bash
cp .env.local.example .env.local
```

El `.env.local` ya viene pre-cargado con los valores correctos para el entorno local. No hace falta modificarlo salvo que el `ANON_KEY` de tu `supabase status` sea diferente al que figura ahí.

> `.env.local` **nunca se commitea** — está en `.gitignore`.

### 6. Iniciar el servidor de desarrollo

```bash
npm run dev
```

Abrí el navegador en la URL que muestra la consola (generalmente `http://localhost:5173`).

---

## Uso diario (segunda vez en adelante)

### Arrancar todo

```bash
# Terminal 1 — base de datos (solo si no está corriendo)
npx supabase start

# Terminal 2 — app Vue
npm run dev
```

### Verificar que la DB está corriendo

```bash
npx supabase status
```

Si dice `Stopped services`, arrancá con `npx supabase start`.

### Parar todo

```bash
npx supabase stop
# Ctrl+C en la terminal del dev server
```

---

## URLs del entorno local

| Servicio | URL | Para qué sirve |
|---|---|---|
| **App Vue** | `http://localhost:5173` | La aplicación principal |
| **Supabase Studio** | `http://127.0.0.1:54323` | Panel visual de la DB (tablas, usuarios, SQL) |
| **API REST** | `http://127.0.0.1:54321` | PostgREST — la API que usa la app |
| **Mailpit** | `http://127.0.0.1:54324` | Emails de auth capturados (no se envían de verdad) |
| **DB directa** | `postgresql://postgres:postgres@127.0.0.1:54322/postgres` | Conexión SQL directa (TablePlus, DBeaver, etc.) |

---

## Usuarios de prueba

Todos tienen contraseña **`test1234`**.

En la pantalla de login (`http://localhost:5173/#/login`), tocá el nombre del usuario e ingresá la contraseña.

| Nombre | Login key | Rol | Pantalla de destino |
|---|---|---|---|
| Lescano | `dueno` | 👑 Dueño | Mesas (acceso a todo) |
| María | `moza1` | 🧑‍💼 Moza | Mesas (solo sus mesas) |
| Cocina | `cocina` | 🍳 Cocina | Pantalla de cocina |
| Caja | `caja` | 💵 Caja | Mesas + reportes |

---

## Flujo de la aplicación

```
http://localhost:5173
  │
  └─→ Carta pública (menú en carrusel, sin login)
        │
        └─→ Punto dorado • (esquina inferior derecha)
              │
              └─→ /login — elegís tu nombre + contraseña
                    │
                    ├─→ moza/caja/dueno → /mesas
                    └─→ cocina → /cocina
```

---

## Comandos útiles

```bash
# Ver estado del stack local
npx supabase status

# Resetear la DB (borra todo y vuelve al estado inicial con seed)
npx supabase db reset

# Abrir Supabase Studio en el browser
npx supabase studio

# Ejecutar SQL directo en la DB local
docker exec -i supabase_db_lescanos-carta psql -U postgres -c "SELECT * FROM perfiles;"

# Ver logs del stack
npx supabase logs

# Parar y limpiar todo (libera puertos)
npx supabase stop
```

---

## Solución de problemas

### "Docker Desktop is a prerequisite" o "cannot find the file specified"

Docker Desktop no está corriendo. Buscalo en el menú Inicio y arrancalo. Esperá a que el ícono aparezca en la barra de tareas antes de correr `npx supabase start`.

### "Port 5173 is in use"

Vite busca automáticamente el siguiente puerto libre (5174, 5175...). La URL correcta aparece en la consola al correr `npm run dev`.

### La app carga pero no muestra datos / error de auth

Verificá que `.env.local` existe y tiene los valores correctos:

```bash
cat .env.local
# Debe mostrar VITE_SUPABASE_URL=http://127.0.0.1:54321
```

Si no existe, crealo:

```bash
cp .env.local.example .env.local
```

### "relation does not exist" en la consola del browser

Las migraciones no se aplicaron. Ejecutá:

```bash
npx supabase db reset
```

### Quiero volver a conectar a producción

Comentá o eliminá `.env.local`. Vite usa `.env` (que apunta al Supabase de producción) cuando no existe `.env.local`.

---

## Estructura del proyecto

```
lescanos-carta/
├── src/
│   ├── pages/
│   │   ├── CartaPage.vue       ← menú público (pantalla inicial)
│   │   ├── LoginPage.vue       ← login del personal
│   │   ├── MesasPage.vue       ← gestión de mesas y pedidos
│   │   ├── KitchenPage.vue     ← pantalla de cocina
│   │   └── ReportsPage.vue     ← reportes y cierre de caja
│   ├── stores/                 ← Pinia (auth, cart)
│   ├── services/supabase.ts    ← cliente Supabase
│   └── router/index.ts         ← rutas y guards por rol
├── supabase/
│   ├── config.toml             ← configuración del stack local
│   ├── migrations/             ← schema de la DB (se versiona con git)
│   └── seed.sql                ← usuarios y datos de prueba
├── menu.js                     ← carta del restaurante (DEFAULT_CARTA)
├── .env                        ← apunta a Supabase de producción
└── .env.local                  ← apunta al Supabase local (NO se commitea)
```
