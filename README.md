# Lescano's — Sistema de gestión y carta digital

Sistema completo de punto de venta y carta digital para el restaurante Lescano's. Incluye menú interactivo para clientes, gestión de mesas con pedidos en tiempo real, pantalla de cocina, reportes diarios y panel de administración de precios.

## Tecnologías


| Capa                   | Tecnología                                                                  |
| ---------------------- | --------------------------------------------------------------------------- |
| Frontend               | HTML + CSS + JavaScript vanilla (sin frameworks)                            |
| Backend                | [Supabase](https://supabase.com) — PostgreSQL + Realtime + Auth             |
| Autenticación          | Supabase Auth (email/contraseña, roles por tabla `perfiles`)                |
| Deploy                 | GitHub Pages vía GitHub Actions                                             |
| Secrets                | Script Python `inject.py` — inyecta secrets en el `dist/` antes de publicar |
| Menú sync              | GitHub API — el panel admin pushea `menu-data.json` directamente al repo    |
| Notificaciones cocina  | Web Audio API (beep de dos tonos)                                           |
| Pantalla cocina        | Screen Wake Lock API (mantiene la tablet encendida)                         |
| Pedidos en tiempo real | Supabase Realtime (`postgres_changes` en tabla `pedidos`)                   |
| Carta digital          | CSS Scroll Snap — carrusel horizontal de páginas del menú                   |


## Pantallas del sistema

### `index.html` — Carta digital + panel admin

Menú interactivo en carrusel para clientes (acceso por QR). El botón `⚙ admin` requiere login como dueño y abre el hub de administración con acceso a todas las secciones.

### `login.html` — Autenticación por roles

Muestra tiles con el personal del restaurante. El usuario toca su nombre, ingresa su contraseña y es redirigido a la pantalla que corresponde a su rol.


| Rol      | Tile  | Pantalla de destino        | Acceso                                      |
| -------- | ----- | -------------------------- | ------------------------------------------- |
| `dueno`  | 👑    | Panel admin (`index.html`) | Todo                                        |
| `moza`   | 🧑‍💼 | Servicio de mesas          | Sus propias mesas y pedidos                 |
| `caja`   | 💵    | Servicio de mesas          | Todas las mesas + reportes + cierre de caja |
| `cocina` | 🍳    | Pantalla de cocina         | Solo lectura de pedidos                     |


### `table-service.html` — Servicio de mesas

- Grilla de mesas con indicador de ocupación (punto dorado = abierta)
- Selector de items del menú con variantes y notas por item
- Resumen dividido en "pendiente de envío" y "ya enviado a cocina"
- Envío a cocina vía Supabase (guarda pedido con items y notas)
- Cierre de mesa: selección de método de pago + cubiertos
- Registro de la moza que atendió cada mesa

### `kitchen.html` — Pantalla de cocina

- Pedidos en tiempo real vía Supabase Realtime
- Tarjetas por pedido con items, notas, mesa y tiempo transcurrido
- Alerta visual y sonora al llegar un pedido nuevo
- Indicador rojo si el pedido supera los 15 minutos
- Botón "Listo" marca el pedido como completado
- Fallback a polling cada 30 segundos si cae la conexión websocket

### `reports.html` — Reportes diarios

- Navegador de fechas (hoy / días anteriores)
- Totales: ventas, mesas cerradas, promedio por cubierto
- Desglose por método de pago (efectivo, débito, crédito, transferencia, MercadoPago, PedidosYa)
- Mesas abiertas activas con subtotal estimado
- Historial de mesas cerradas con moza, método, duración e items
- Top 8 productos del día por cantidad
- Cierre de caja (queda registrado en tabla `cierres`)
- Exportación CSV compatible con Excel

## Estructura de base de datos (Supabase)

```
perfiles       — usuarios del sistema (id, nombre, login_key, rol, emoji, activo)
sesiones       — mesas abiertas/cerradas (mesa, estado, cubiertos, moza_id, moza_nombre)
pedidos        — cada envío a cocina (sesion_id, estado, listo_at)
pedido_items   — items de cada pedido (nombre, precio, qty, nota, seccion)
pagos          — pago al cerrar mesa (sesion_id, metodo, monto)
cierres        — cierre de caja diario (fecha, totales por método)
config         — configuración dinámica (num_mesas, etc.)
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

El tile aparece automáticamente en `login.html` la próxima vez que se abre.

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

El cambio es inmediato. La próxima vez que el usuario ingrese, usa la contraseña nueva.

### Roles disponibles


| Rol    | SQL        | Emoji sugerido |
| ------ | ---------- | -------------- |
| Dueño  | `'dueno'`  | 👑             |
| Moza   | `'moza'`   | 🧑‍💼          |
| Caja   | `'caja'`   | 💵             |
| Cocina | `'cocina'` | 🍳             |


## Flujo de trabajo

### Inicio del turno

1. El dueño abre `login.html` y distribuye la tablet/teléfono a cada moza
2. Cada moza toca su nombre e ingresa su contraseña
3. La pantalla de cocina se deja abierta en `kitchen.html` (login con rol cocina)

### Durante el servicio

```
Moza selecciona mesa → elige items + notas → "Enviar a cocina"
  → Supabase guarda pedido
  → Cocina recibe notificación en tiempo real + beep
  → Cocinero marca "Listo" cuando el plato está
```

### Cierre de mesa

```
Moza o Caja → "Cerrar mesa" → selecciona método de pago + cubiertos
  → Sesión queda cerrada en Supabase con todos los datos
  → Aparece en reportes del día
```

### Cierre de caja (dueño o caja)

1. Abrir `reports.html` con la fecha del día
2. Revisar totales y desglose por método
3. Presionar "Cierre de caja" — queda registrado en Supabase
4. Exportar CSV si se necesita para contabilidad

### Actualización del menú

1. Dueño abre el panel admin desde `index.html`
2. Modifica precios y productos en la sección "Gestión de Precios"
3. Presiona "Publicar" — el sistema pushea `menu-data.json` al repositorio vía GitHub API
4. GitHub Actions corre el build en ~2 minutos y el menú queda actualizado en producción

### Cambiar la cantidad de mesas

1. Dueño abre el panel admin desde `index.html`
2. En el hub, campo "Cantidad de mesas" → ingresar el nuevo número → "Guardar"
3. El cambio se aplica inmediatamente sin deploy

## Ramas


| Rama                       | Propósito                                                      |
| -------------------------- | -------------------------------------------------------------- |
| `master`                   | Producción — lo que está live en GitHub Pages                  |
| `feature/supabase-backend` | Desarrollo activo (nunca tocar mientras el local está abierto) |
| `release/v2.0-supabase`    | Staging — listo para mergear a master cuando cierra el local   |


## Deploy

El CI/CD corre automáticamente al hacer push a `master`. El workflow:

1. Copia los archivos a `dist/`
2. Corre `inject.py` — reemplaza los placeholders con los secrets de GitHub Actions
3. Publica `dist/` en GitHub Pages

**Secrets necesarios en GitHub Actions:**


| Secret       | Descripción                                              |
| ------------ | -------------------------------------------------------- |
| `WA_NUMBER`  | Número de WhatsApp para envío de pedidos                 |
| `MENU_TOKEN` | GitHub PAT para que el panel admin pueda pushear el menú |


> `NUM_MESAS` y `ADMIN_PWD` ya no son necesarios — se eliminaron en v2.0.

