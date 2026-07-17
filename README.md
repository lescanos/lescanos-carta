# Lescano's — Sistema de gestión integral

Sistema completo de punto de venta y carta digital para Lescano's Fast Food. Cubre el ciclo completo de una mesa: desde que el cliente escanea el QR hasta el cierre de caja del día.

**URL de producción:** https://lescanos.github.io/lescanos-carta/

---

## Índice

1. [Descripción general](#descripción-general)
2. [Stack tecnológico](#stack-tecnológico)
3. [Roles del sistema](#roles-del-sistema)
4. [Pantallas](#pantallas)
5. [Base de datos](#base-de-datos)
6. [Seguridad y permisos](#seguridad-y-permisos)
7. [Gestión de usuarios](#gestión-de-usuarios)
8. [Gestión del menú y precios](#gestión-del-menú-y-precios)
9. [Deploy y CI/CD](#deploy-y-cicd)
10. [Entorno local](#entorno-local)
11. [Tests](#tests)

---

## Descripción general

El sistema resuelve tres necesidades del restaurante:

| Necesidad | Solución |
|-----------|----------|
| Carta digital para clientes | Menú interactivo por QR, sin login, siempre actualizado |
| Operación de mesas en tiempo real | Pedidos sincronizados entre moza, cocina y caja |
| Administración sin dependencia técnica | Precios, usuarios y configuración desde el panel admin |

---

## Stack tecnológico

| Capa | Tecnología |
|------|-----------|
| Frontend | Vue 3 + Vite + TypeScript + `<script setup>` |
| Estado global | Pinia (stores: `auth`, `cart`) |
| Estilos | Tailwind CSS + tokens de diseño custom (gold, dark, cream) |
| Backend / DB | Supabase — PostgreSQL 17 + PostgREST + GoTrue Auth |
| Tiempo real | Supabase Realtime (`postgres_changes` en `pedidos` y `sesiones`) |
| Funciones serverless | Supabase Edge Functions (Deno) — `admin-users` |
| Deploy | GitHub Actions → GitHub Pages |
| Tests | Vitest (lógica de negocio pura) |
| Audio | Web Audio API (beep cocina) |
| Wake Lock | Screen Wake Lock API (tablet cocina no se apaga) |

---

## Roles del sistema

| Rol | Emoji | Pantalla inicial | Permisos |
|-----|-------|-----------------|----------|
| `dueno` | 👑 | Mesas | Acceso total: mesas, cocina, reportes, admin, menú, usuarios |
| `moza` | 🧑‍💼 | Mesas | Sus propias mesas y pedidos |
| `caja` | 💵 | Mesas | Todas las mesas + reportes + cierre de caja |
| `cocina` | 🍳 | Cocina | Solo lectura de pedidos pendientes |

### Cómo se maneja el login

Los usuarios **no tienen email real**. El sistema usa `login_key@lescanos.local` internamente (ej: `maria@lescanos.local`). El personal solo ve tiles con su nombre y emoji — ingresa su contraseña y listo.

El punto `•` dorado en la esquina inferior derecha de la carta digital es el acceso al login del personal. Es intencionalmente sutil para que los clientes no lo encuentren.

---

## Pantallas

### `/` — Carta digital (pública, acceso por QR)

- Carrusel horizontal con scroll-snap: una "página" por slide
- Panel izquierdo oscuro: branding, logo, datos de contacto
- Panel derecho crema: contenido del menú con scroll vertical
- Secciones con ítems, precios por columna (ej: Solo / Con papas) o precio único
- Slide especial de Promos con diseño diferenciado
- **Los precios se cargan desde Supabase al iniciar** y se cachean en `localStorage` como fallback offline
- No requiere autenticación — RLS permite lectura a `anon`

### `/login` — Login del personal

- Tiles con nombre y emoji de cada perfil activo
- Campo de contraseña al seleccionar un perfil
- Redirección automática al rol correspondiente

### `/mesas` — Servicio de mesas

**Grilla de mesas**
- Tiles con indicador de estado (punto dorado = abierta)
- Muestra la moza asignada y subtotal estimado
- Confirmación al abrir una mesa cerrada (evita toques accidentales)
- Bloqueo de mesa ajena: moza solo puede entrar a su mesa o al dueño/caja

**Dentro de una mesa**
- Selector de menú con secciones colapsables
- Ítems con variantes de precio (multi-columna)
- Notas por ítem (campo libre de texto)
- Ajuste de cubiertos desde el header
- División del carrito: pendiente de envío / ya enviado a cocina
- Envío a cocina: guarda en Supabase y notifica en tiempo real
- **Tracking de entrega ítem por ítem**: cada ítem enviado tiene un botón que la moza toca al entregarlo a la mesa (gris = sin entregar, dorado = parcial, verde = entregado). El estado persiste en Supabase y se sincroniza en tiempo real entre dispositivos. Banner "Todo entregado ✓" cuando la mesa está completa.
- **Bebidas no van a cocina**: ítems de secciones BEBIDAS SIN ALCOHOL, CERVEZAS y TRAGOS se guardan como pedido `tipo='barra'` — la cocina nunca los ve. La moza los entrega directamente desde la barra.
- **Estado del pedido en tiempo real**: los ítems "Ya enviado" se agrupan por pedido y muestran un badge de estado que se actualiza en tiempo real sin refresh: `En cocina` (dorado), `✓ Listo` (verde) cuando cocina marca el pedido listo, `🍺 Barra` (azul) para bebidas. La moza puede responder al cliente sobre el estado de su pedido sin ir a la cocina.

**Tipos de sesión**
| Tipo | Descripción |
|------|-------------|
| `mesa` | Mesa del local (default) |
| `envio` | Delivery — guarda nombre, teléfono, dirección y referencia del cliente |
| `llevar` | Para llevar — sin datos de cliente |

**Delivery**
- Formulario con datos del cliente
- Botón de WhatsApp que genera mensaje pre-formateado para el cadete con dirección e ítems

**Cierre de mesa**
- Selección de método de pago (efectivo, débito, crédito, transferencia, MercadoPago, PedidosYa)
- Soporte de split billing: múltiples pagos por sesión con distintos métodos
- Registro de moza, cubiertos y hora de cierre

**Cambios y cancelaciones**
- Flujo diferenciado con tipo de pedido: `pedido` / `cambio` / `cancelacion`
- Las tarjetas en cocina cambian de color según el tipo (naranja = cambio, rojo = cancelación)
- **Cancelación con descuento inmediato**: al cancelar un ítem ya enviado, se marca como `cancelado=true` en la BD, se descuenta del total al instante, y queda visible tachado en rojo con etiqueta "Cancelado". Los botones de entrega/cambio/cancelar se ocultan. La actualización llega por Realtime sin necesidad de refresh.

**Cierre de mesa**
- **Bloqueo por ítems sin entregar**: el botón "Cerrar mesa" se deshabilita si hay ítems (cocina o barra) que la moza no marcó como entregados. Se muestra un contador "X item(s) sin entregar" en ámbar. El bloqueo aplica a comida y bebidas por igual — el criterio es el ✓ de entrega de la moza, no el estado de cocina.

**Notificaciones**
- Banner "Pedido listo — Mesa X" visible en cualquier pantalla cuando cocina marca listo
- Beep de audio al recibir la notificación

### `/cocina` — Pantalla de cocina

- Pedidos en tiempo real vía Supabase Realtime (sin refresh)
- Tarjetas con ítems, notas, mesa y tiempo transcurrido
- Indicador rojo si el pedido supera los 15 minutos
- Alerta sonora diferenciada: beep normal para pedidos, beep distinto para cambios/cancelaciones
- Botón "Listo" registra `listo_at` y dispara notificación a mesas
- Reloj digital en header actualizado cada segundo
- Wake Lock: la tablet no se apaga mientras la pantalla está activa
- Sección "Listos hoy" se limpia al hacer cierre de caja
- **Bebidas filtradas**: pedidos `tipo='barra'` nunca aparecen en cocina — la cocina solo ve comida

### `/reportes` — Reportes y cierre de caja

- Navegador de fechas (hoy / días anteriores)
- **Totales del día**: ventas, mesas cerradas, promedio por cubierto
- **Desglose por método de pago**: tabla con total y cantidad por método
- **Mesas activas**: subtotales estimados de mesas todavía abiertas
- **Historial completo**: mesas cerradas con moza, método, duración e ítems
- **Top 8 productos**: ranking del día por cantidad vendida
- **Cierre de caja**: registra el cierre, cierra todas las mesas abiertas, limpia cocina
- **Exportación CSV**: compatible con Excel, incluye detalle de todas las sesiones

### `/admin/usuarios` — Panel de administración

Acceso exclusivo para rol `dueno`. Tres secciones en tabs:

**Tab: Usuarios**
- Lista de todo el personal con estado (activo/inactivo)
- Crear usuario: nombre, clave de login, rol, emoji, contraseña inicial
- Editar perfil: nombre, clave, rol, emoji
- Cambiar contraseña
- Activar/desactivar (sin borrar historial)
- Eliminar usuario permanentemente

**Tab: Menú**
- Lista completa del menú organizada por sección
- Precios editables inline — tocar el campo, editar, salir del campo
- **Auto-save**: se guarda en Supabase automáticamente al salir de cada campo
- Reflejo inmediato en la carta digital para todos los dispositivos
- **No requiere código ni deploy para cambiar un precio**

**Tab: Configuración**
- Costo de envío a domicilio (se suma a todos los pedidos tipo `envio`)

---

## Base de datos

### Esquema

```
perfiles         id, nombre, login_key, rol, emoji, activo
sesiones         id, mesa, estado, tipo, cubiertos, moza_id, moza_nombre,
                 cliente_nombre, cliente_telefono, cliente_direccion,
                 cliente_referencia, closed_at, created_at
pedidos          id, sesion_id, estado, tipo, listo_at, created_at
                 tipo: 'pedido' | 'cambio' | 'cancelacion' | 'barra'
pedido_items     id, pedido_id, sesion_id, nombre, precio, qty, nota, seccion,
                 entregado_qty,  ← tracking de entrega ítem por ítem
                 cancelado       ← true cuando la moza cancela el ítem
pagos            id, sesion_id, metodo, monto, created_at
cierres          id, fecha, total, efectivo, debito, credito,
                 transferencia, mercadopago, pedidosya, notas, created_at
config           clave, valor  (num_mesas, costo_envio)
menu_secciones   id, pagina, pagina_titulo, pagina_tipo, pagina_subtitulo,
                 seccion_orden, emoji, titulo, nota, columnas,
                 va_a_cocina  ← false para secciones de bebidas
menu_items       id, seccion_id, item_orden, nombre, descripcion, precios[]
```

### Migraciones

Las migraciones están en `supabase/migrations/` y se aplican automáticamente con `supabase db push`.

| Migración | Descripción |
|-----------|-------------|
| `20240101` | Schema inicial: todas las tablas base |
| `20240102` | `pedido_items.sesion_id` para filtro cocina |
| `20240103` | Soporte delivery y tipo de pedido en sesiones |
| `20240104` | `config.costo_envio` |
| `20240105` | Vista `perfiles_publicos`, RLS financiero |
| `20240106` | Drop FK `perfiles → auth.users` (permite seed limpio) |
| `20240107` | RLS de escritura en perfiles (update/insert/delete) + grants |
| `20240108` | Tablas `menu_secciones` y `menu_items` con RLS |
| `20240109` | Seed inicial del menú completo |
| `20240110` | Precios multi-columna para TORPEDOS; split CARLITOS / TOSTADOS |
| `20240111` | `pedido_items.entregado_qty` — tracking de entrega ítem por ítem |
| `20240112` | `pedido_items` en publicación Realtime |
| `20240113` | RLS UPDATE columna-level en `entregado_qty`; cocina bloqueada |
| `20240114` | `pedidos.tipo = 'barra'`; `menu_secciones.va_a_cocina`; bebidas marcadas como barra |
| `20240115` | Brand config: seed de claves `brand_*` en tabla `config` (nombre, dominio, contacto) |
| `20240116` | RLS: política `anon` para leer claves `brand_%` de `config` (necesario para login) |
| `20240117` | `pedido_items.cancelado` — columna para cancelación de ítems con descuento inmediato |

---

## Seguridad y permisos

### Row Level Security (RLS)

Todas las tablas tienen RLS habilitado. Resumen de políticas:

| Tabla | Anon | Authenticated | Service role |
|-------|------|---------------|-------------|
| `perfiles_publicos` (view) | SELECT | SELECT | ALL |
| `perfiles` | — | SELECT + UPDATE (propio o dueño) | ALL |
| `sesiones` | — | SELECT + write (según rol) | ALL |
| `pedidos` | — | SELECT + write | ALL |
| `pedido_items` | — | SELECT + write; UPDATE `entregado_qty` solo moza/caja/dueño | ALL |
| `pagos` | — | SELECT + write | ALL |
| `cierres` | — | SELECT + write (caja/dueño) | ALL |
| `config` | SELECT claves `brand_%` (sin auth) | SELECT + write (dueño) | ALL |
| `menu_secciones` | SELECT | SELECT + write (dueño) | ALL |
| `menu_items` | SELECT | SELECT + write (dueño) | ALL |

### Auto-logout por inactividad

El personal (moza, caja, dueño) es deslogueado automáticamente si pasa **1 hora sin interacción** con la plataforma. Cualquier toque, click o scroll reinicia el timer. Al expirar se llama a `auth.logout()` y se redirige a `/login`.

La pantalla de cocina es la **única excepción**: la tablet está diseñada para estar encendida toda la noche sin interacción, por lo que nunca se desloguea por inactividad — solo al tocar "Salir" explícitamente.

Implementado como composable `useInactivityLogout` en `src/composables/` — se agrega a las páginas que deben forzar el timeout, y se omite en `KitchenPage`.

### Edge Function: `admin-users`

La creación, edición y eliminación de usuarios de GoTrue **solo puede hacerse con la service role key**, que nunca llega al cliente. La edge function `admin-users` valida que el JWT del caller corresponde a un perfil con `rol = 'dueno'` antes de ejecutar cualquier operación.

---

## Gestión de usuarios

Todo se hace desde el panel admin en la app — sin SQL, sin Dashboard de Supabase.

**Crear un usuario:**
1. Ingresar como Lescano (dueño)
2. Ir a Admin → Tab "Usuarios" → "+ Nuevo"
3. Completar nombre, clave de login, contraseña inicial y rol
4. Guardar — el usuario aparece en el login inmediatamente

**Cambiar contraseña:**
1. Admin → Tab "Usuarios" → ícono 🔑 del usuario
2. Ingresar nueva contraseña → Guardar

**Desactivar un usuario** (el historial se conserva):
1. Admin → Tab "Usuarios" → "Desactivar"
2. El tile desaparece del login, el historial de mesas queda intacto

---

## Gestión del menú y precios

**Sin código. Sin deploy. Cambios en segundos.**

1. Ingresar como Lescano (dueño)
2. Ir a Admin → Tab "Menú"
3. Encontrar el ítem (están organizados por sección igual que la carta)
4. Tocar el precio → editarlo → salir del campo
5. El precio se guarda en Supabase automáticamente
6. La carta digital del QR refleja el cambio en la próxima carga

**Arquitectura del menú:**
- Los precios viven en `menu_items.precios` (array de texto, uno por columna)
- La carta digital (`/`) carga desde Supabase al iniciar y cachea en `localStorage`
- Si Supabase no está disponible, muestra la versión cacheada del último uso
- `menu.js` queda como fallback de último recurso para el primer uso offline

---

## Deploy y CI/CD

**El deploy es automático al hacer push a `master`.**

```
git push origin master
→ GitHub Actions: npm ci && npm run build
→ Variables VITE_* inyectadas desde GitHub Secrets
→ dist/ publicado en GitHub Pages
→ URL activa en ~2 minutos
```

### GitHub Secrets requeridos

| Secret | Valor |
|--------|-------|
| `VITE_SUPABASE_URL` | `https://hfayvobhkkkdrijzsmtk.supabase.co` |
| `VITE_SUPABASE_ANON_KEY` | La anon key pública del proyecto |
| `VITE_WA_NUMBER` | Número de WhatsApp del negocio (ej: `5493412282814`) |

### Supabase

```bash
# Aplicar migraciones a cloud
npx supabase link --project-ref hfayvobhkkkdrijzsmtk
npx supabase db push

# Deploy de edge functions
npx supabase functions deploy admin-users
```

---

## Entorno local

### Requisitos

- Node.js 22+
- Docker Desktop (para Supabase local)
- PowerShell (Windows) o Bash

### Setup inicial

```bash
# 1. Instalar dependencias
npm install

# 2. Iniciar Supabase local
npx supabase start

# 3. Copiar variables de entorno local
cp .env.local.example .env.local
# (las URLs ya están seteadas para local)

# 4. Iniciar servidor de desarrollo
npm run dev
```

### Reset de base de datos local

Después de cada `db reset`, los usuarios de GoTrue se pierden. Restaurar con:

```powershell
powershell.exe -ExecutionPolicy Bypass -File ./supabase/seed-auth.ps1
```

El script crea los usuarios en GoTrue y sincroniza los UUIDs reales en la tabla `perfiles`. Contraseña para todos: `test1234`.

### Comandos útiles

```bash
npm run dev          # Servidor de desarrollo
npm run build        # Build de producción
npm run type-check   # Verificación TypeScript
npm run test         # Tests unitarios (Vitest)
npm run test:watch   # Tests en modo watch

npx supabase start   # Iniciar stack local
npx supabase stop    # Detener stack local
npx supabase db reset  # Reset completo (borra datos)
npx supabase studio  # Abrir Studio local (localhost:54323)
```

---

## Tests

Los tests cubren la lógica pura de negocio (sin dependencias de red ni de Vue).

```bash
npm run test
```

**Cobertura actual:**

| Módulo | Tests | Descripción |
|--------|-------|-------------|
| `menuMapper.ts` | 12 | Conversión de filas DB a estructura `MenuPagina[]`, incluyendo `va_a_cocina` |
| `entrega.ts` | 10 | Lógica de tracking de entrega (`nextEntregadoQty`, `entregadoStatus`) |
| `sessionGroups.ts` | 9 | Agrupamiento de items por pedido (`buildSessionGroups`) |

Los tests verifican:
- Mapeo de páginas regulares y de promos
- Items con precio único vs. multi-precio (por columnas)
- Ordenamiento de páginas, secciones e ítems
- Propagación de emoji, nota, columnas y `va_a_cocina`
- Casos borde: sección sin ítems, descripción nula, arrays vacíos
- Ciclo de tracking: 0 → 1 → N → reset a 0
- Estados de entrega: `none`, `partial`, `full`
- Agrupamiento de items por pedido: grupos separados, orden cronológico, items sin pedido ignorados, tipo barra y estado preservados
