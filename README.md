# Lescano's — Sistema de gestión y carta digital

Sistema completo de punto de venta y carta digital para el restaurante Lescano's. Incluye menú interactivo para clientes, gestión de mesas con pedidos en tiempo real, pantalla de cocina, reportes diarios y panel de administración de precios.

## Tecnologías

| Capa                   | Tecnología                                                                |
| ---------------------- | ------------------------------------------------------------------------- |
| Frontend               | Vue 3 + Vite + TypeScript                                                 |
| Estado                 | Pinia (stores reactivos por dominio)                                      |
| Estilos                | Tailwind CSS + tokens de diseño (gold, dark, cream)                       |
| Backend                | [Supabase](https://supabase.com) — PostgreSQL + Realtime + Auth           |
| Autenticación          | Supabase Auth (email/contraseña, roles por tabla `perfiles`)              |
| Deploy                 | GitHub Pages vía GitHub Actions + `inject.py`                             |
| Menú                   | `menu.js` (fallback global `DEFAULT_CARTA`) + `localStorage`              |
| Notificaciones cocina  | Web Audio API (beep de dos tonos)                                         |
| Pantalla cocina        | Screen Wake Lock API (mantiene la tablet encendida)                       |
| Pedidos en tiempo real | Supabase Realtime (`postgres_changes` en tablas `pedidos` y `sesiones`)   |
| Carta digital          | CSS Scroll Snap — carrusel horizontal de páginas del menú                 |


## Flujo de trabajo

### Acceso a la aplicación

```
Usuario abre la URL
  → Ve la carta digital (menú en carrusel, solo lectura)
  → Si es personal: toca el punto dorado • en la esquina inferior derecha
  → Se abre la pantalla de login
  → Elige su nombre, ingresa su contraseña
  → Es redirigido a su pantalla según su rol
```

> El punto `•` es intencionalmente sutil — está pensado para que los clientes no lo vean pero el personal lo conozca.

### Roles y destinos

| Rol      | Emoji | Pantalla de destino            | Acceso                                      |
| -------- | ----- | ------------------------------ | ------------------------------------------- |
| `dueno`  | 👑    | Servicio de mesas + todo       | Todo (mesas, cocina, reportes, config)      |
| `moza`   | 🧑‍💼 | Servicio de mesas              | Sus propias mesas y pedidos                 |
| `caja`   | 💵    | Servicio de mesas              | Todas las mesas + reportes + cierre de caja |
| `cocina` | 🍳    | Pantalla de cocina             | Solo lectura de pedidos                     |


## Pantallas del sistema

### `/` — Carta digital (pública)

Menú del restaurante en carrusel horizontal para clientes (accesible por QR). Muestra todas las páginas del menú: secciones con items y precios, y una slide especial de promos. No requiere login.

El panel izquierdo (oscuro) muestra el branding y datos de contacto. El panel derecho (crema) muestra el contenido del menú con scroll vertical dentro de cada página.

El botón `•` en la esquina inferior derecha (apenas visible) lleva al login del personal.

### `/login` — Login del personal

Tiles con el personal del restaurante. El usuario toca su nombre, ingresa su contraseña y es redirigido a la pantalla que corresponde a su rol.

### `/mesas` — Servicio de mesas

- Grilla de mesas con indicador de ocupación (punto dorado = abierta) y nombre de la moza asignada
- Confirmación al tocar una mesa cerrada — evita abrir sesiones por accidente
- Selector de items del menú con variantes y notas por item
- Cubiertos ajustables desde el header del menú (se guardan en Supabase al instante)
- Resumen dividido en "pendiente de envío" y "ya enviado a cocina"
- Envío a cocina vía Supabase (guarda pedido con items y notas)
- Botón "Volver a mesas" después de enviar a cocina (la mesa queda abierta para más pedidos)
- Notificación sonora + banner "Pedido listo — Mesa X" visible en **cualquier pantalla** al marcar la cocina
- Cierre de mesa: selección de método de pago + cubiertos
- Registro de la moza que atendió cada mesa
- **Envíos a domicilio**: formulario de datos del cliente, sesión tipo `envio`, botón WhatsApp pre-formateado con dirección e items para el cadete
- Cambios y cancelaciones: flujo diferenciado con tarjetas de color (naranja = cambio, rojo = cancelación) en cocina

### `/cocina` — Pantalla de cocina

- Pedidos en tiempo real vía Supabase Realtime
- Tarjetas por pedido con items, notas, mesa y tiempo transcurrido
- Alerta visual y sonora al llegar un pedido nuevo (beep) o un cambio/cancelación (beep diferente)
- Indicador rojo si el pedido supera los 15 minutos
- Botón "Listo" marca el pedido como completado y registra `listo_at`
- Reloj digital en el header (hora actualizada cada segundo)
- Grilla reactiva que se recarga en tiempo real sin necesidad de refresh
- Wake Lock: la tablet no se apaga mientras la pantalla está abierta
- Al confirmar el cierre de caja, la sección "Listos hoy" se limpia automáticamente vía Realtime

### `/reportes` — Reportes diarios

- Navegador de fechas (hoy / días anteriores)
- Totales: ventas, mesas cerradas, promedio por cubierto
- Desglose por método de pago (efectivo, débito, crédito, transferencia, MercadoPago, PedidosYa)
- Mesas abiertas activas con subtotal estimado
- Historial de mesas cerradas con moza, método, duración e items
- Top 8 productos del día por cantidad
- Cierre de caja: registra el cierre, **cierra todas las mesas abiertas** y limpia la pantalla de cocina
- Exportación CSV compatible con Excel


## Estructura de base de datos (Supabase)

```
perfiles       — usuarios del sistema (id, nombre, login_key, rol, emoji, activo)
sesiones       — mesas abiertas/cerradas (mesa, estado, cubiertos, moza_id, moza_nombre,
                 tipo, cliente_nombre, cliente_telefono, cliente_direccion, cliente_referencia)
pedidos        — cada envío a cocina (sesion_id, estado, listo_at, tipo)
pedido_items   — items de cada pedido (nombre, precio, qty, nota, seccion)
pagos          — pago al cerrar mesa (sesion_id, metodo, monto)
cierres        — cierre de caja diario (fecha, totales por método)
config         — configuración dinámica (num_mesas, etc.)
```

> **Nota:** El campo `tipo` en `sesiones` puede ser `'mesa'` (default) o `'envio'` (delivery). Las columnas `cliente_*` solo se usan para envíos.

> El campo `tipo` en `pedidos` puede ser `'pedido'` (default), `'cambio'` o `'cancelacion'`. Las tarjetas en cocina cambian de color según el tipo.

### Migraciones pendientes

Si la base fue creada antes de las últimas features, ejecutar en Supabase SQL Editor:

```sql
-- Soporte delivery en sesiones
alter table sesiones
  add column if not exists tipo text default 'mesa',
  add column if not exists cliente_nombre text,
  add column if not exists cliente_telefono text,
  add column if not exists cliente_direccion text,
  add column if not exists cliente_referencia text;

-- Tipo de pedido (cambio / cancelación)
alter table pedidos
  add column if not exists tipo text default 'pedido';

-- RLS: mozas pueden ver todas las sesiones (para el bloqueo de mesa ajena)
drop policy if exists "sesiones_select" on sesiones;
create policy "sesiones_select" on sesiones
  for select using (auth.role() = 'authenticated');
```


## Gestión de usuarios

### Agregar una moza u otro usuario

**Paso 1** — En Supabase Dashboard: `Authentication → Users → Add user → Create new user`

| Campo             | Valor                                                           |
| ----------------- | --------------------------------------------------------------- |
| Email             | `lucia@lescanos.local` (el texto antes del `@` es el login_key) |
| Password          | La contraseña que le vas a dar                                  |
| Auto Confirm User | ✅ tildado                                                       |

**Paso 2** — Copiar el **UUID** del usuario recién creado (columna UID).

**Paso 3** — En `SQL Editor`, ejecutar:

```sql
insert into perfiles (id, nombre, login_key, rol, emoji)
values ('PEGAR-UUID-AQUI', 'Lucía', 'lucia', 'moza', '🧑‍💼');
```

El tile aparece automáticamente en `/login` la próxima vez que se abre.

### Desactivar un usuario (sin borrar historial)

```sql
update perfiles set activo = false where nombre = 'Lucía';
```

### Cambiar contraseña

> Los usuarios usan emails `@lescanos.local` (no reales), por eso el envío de recovery no funciona. La única forma es editarla directamente.

1. Ir a **Supabase Dashboard → Authentication → Users**
2. Buscar al usuario por nombre o email (ej: `lucia@lescanos.local`)
3. Hacer clic en los **tres puntos** (⋯) a la derecha → **Edit user**
4. En el campo **Password**, escribir la nueva contraseña
5. Hacer clic en **Save**

### Roles disponibles

| Rol    | SQL        | Emoji sugerido |
| ------ | ---------- | -------------- |
| Dueño  | `'dueno'`  | 👑             |
| Moza   | `'moza'`   | 🧑‍💼          |
| Caja   | `'caja'`   | 💵             |
| Cocina | `'cocina'` | 🍳             |


## Deploy

El CI/CD corre automáticamente al hacer push a `master`. El workflow:

1. Instala dependencias e instala `npm run build`
2. Corre `inject.py` — reemplaza los placeholders `{{VITE_SUPABASE_URL}}` / `{{VITE_SUPABASE_ANON_KEY}}` en el `dist/` con los secrets de GitHub Actions
3. Publica `dist/` en GitHub Pages

**Secrets necesarios en GitHub Actions:**

| Secret                 | Descripción                              |
| ---------------------- | ---------------------------------------- |
| `VITE_SUPABASE_URL`    | URL del proyecto Supabase                |
| `VITE_SUPABASE_ANON_KEY` | Clave pública anon de Supabase         |

### Actualización del menú

El menú se define en `menu.js` como variable global `DEFAULT_CARTA`. Para actualizar precios:

1. Editar `menu.js` con los nuevos precios
2. Hacer commit y push a `master`
3. GitHub Actions corre el build en ~2 minutos y el menú queda actualizado en producción

> El sistema también usa `localStorage` como cache: si el menú fue guardado localmente (sesiones anteriores), lo prioriza. Limpiar el localStorage del browser fuerza recargar desde `menu.js`.

### Cantidad de mesas

La cantidad de mesas se configura en la tabla `config` de Supabase:

```sql
insert into config (clave, valor)
values ('num_mesas', '8')
on conflict (clave) do update set valor = excluded.valor;
```

O desde `/mesas` si el rol tiene permisos de config.
