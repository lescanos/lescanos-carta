# Demo — Sistema de gestión Lescano's

Guía paso a paso para mostrar el sistema en funcionamiento. Cada sección es un bloque independiente — podés seguir el orden completo o saltar a lo que más le interese a la audiencia.

**URL:** https://lescanos.github.io/lescanos-carta/

---

## Antes de empezar

Tener abiertos en distintas pestañas/dispositivos:
- **Pestaña 1 / celular del cliente:** la URL raíz (carta digital)
- **Pestaña 2 / tablet de moza:** `/login` → ingresar como Maria
- **Pestaña 3 / tablet de cocina:** `/login` → ingresar como Cocina
- **Pestaña 4 / celular del dueño:** `/login` → ingresar como Lescano

---

## Bloque 1 — La carta digital (lo que ve el cliente)

> *"Esto es lo que aparece cuando el cliente escanea el QR en la mesa."*

**Pasos:**
1. Abrir la URL raíz en el celular o tablet
2. Deslizar horizontalmente entre las páginas del menú
3. Mostrar el panel izquierdo (branding) y el panel derecho (contenido)
4. Señalar los precios con columnas (Solo / Con papas) en hamburguesas
5. Llegar hasta la slide de Promos — mostrar el diseño diferenciado
6. Volver a la primera página

**Punto clave:**
> *"El cliente no necesita app, no necesita wifi propio, no necesita nada. Solo escanea y ve la carta actualizada al instante."*

---

## Bloque 2 — Login del personal

> *"El acceso del personal está escondido en la carta misma. Los clientes no lo ven."*

**Pasos:**
1. En la carta digital, señalar el punto dorado `•` en la esquina inferior derecha
2. Tocarlo — se abre la pantalla de login
3. Mostrar los tiles con nombre y emoji de cada persona
4. Tocar "Maria" → aparece el campo de contraseña
5. Ingresar → redirige al servicio de mesas

**Punto clave:**
> *"No hay URL separada que memorizar. El personal sabe que el punto está ahí, los clientes no."*

---

## Bloque 3 — Servicio de mesas (flujo completo de una mesa)

> *"Esto es lo que usa la moza durante toda la noche."*

### 3.1 Abrir una mesa

1. Mostrar la grilla de mesas (tiles con puntos grises = cerradas)
2. Tocar la Mesa 1
3. Confirmar en el diálogo de apertura
4. La mesa queda abierta — punto dorado visible en la grilla

### 3.2 Tomar un pedido

1. Dentro de la mesa, explorar el selector de menú
2. Abrir la sección "Hamburguesas"
3. Tocar "Elmer Fudd" → elegir variante "Con papas" → agregar
4. Agregar otro ítem con una nota (ej: "Taz — sin cebolla")
5. Mostrar el carrito con los ítems en "pendiente de envío"
6. Ajustar cubiertos en el header (subir a 2)

### 3.3 Enviar a cocina

1. Tocar "Enviar a cocina"
2. El carrito se limpia — los ítems pasan a "Ya enviado"
3. **Cambiar a la pestaña de cocina** — mostrar que el pedido llegó en tiempo real, sin refresh
4. Señalar: nombre de la mesa, ítems, notas, tiempo transcurrido

**Punto clave:**
> *"La cocina ve el pedido en el instante en que la moza lo envía. Sin papel, sin gritos, sin confusiones."*

### 3.4 Agregar una bebida (no va a cocina)

1. Volver a la mesa, ir a la página de bebidas
2. Agregar una Coca-Cola o una cerveza
3. Tocar "Enviar a cocina"
4. **Cambiar a la pestaña de cocina** — la bebida NO aparece
5. Volver a la mesa — la bebida aparece en "Ya enviado" igual que la comida

**Punto clave:**
> *"Las bebidas las entrega la moza directamente desde la barra, no pasan por cocina. El sistema las registra en la cuenta pero no molesta al cocinero."*

### 3.5 Tracking de entrega ítem por ítem

> *"Cuando hay muchos pedidos, la moza puede perder track de qué llegó a cada mesa."*

1. En la sección "Ya enviado" de la mesa, mostrar los botones de entrega por ítem
2. Tocar el botón de una hamburguesa — cambia a dorado (parcial si había más de uno)
3. Tocar de nuevo — verde con ✓ (todo entregado)
4. Tocar de nuevo — vuelve a gris (reset)
5. Entregar todos los ítems — aparece el banner "Todo entregado ✓" al final

**Punto clave:**
> *"La moza sabe exactamente qué salió a cada mesa. Útil cuando se lleva primero la bebida y después la comida, o cuando una mesa pide por partes."*

### 3.6 Marcar pedido listo (desde cocina)

1. En la pestaña de cocina: tocar "Listo" en el pedido
2. **Volver a la pestaña de mesas** — mostrar la notificación "Pedido listo — Mesa 1"
3. La notificación es visible aunque la moza esté en otra mesa o pantalla

### 3.7 Cerrar la mesa con pago

1. Volver a la Mesa 1
2. Tocar "Cerrar mesa"
3. Seleccionar método de pago (ej: MercadoPago)
4. Confirmar
5. La mesa vuelve a gris en la grilla — lista para el próximo cliente

---

## Bloque 4 — Pantalla de cocina

> *"Esta pantalla corre en una tablet fija en la cocina, siempre encendida."*

**Mostrar:**
- Las tarjetas de pedidos con ítems y notas
- El reloj en el header (actualizado cada segundo)
- Un pedido con más de 15 minutos — tarjeta en rojo
- El botón "Listo" para marcar un pedido completo

**Hacer en vivo:**
1. Desde la pestaña de moza, enviar un pedido de comida — aparece en cocina
2. Desde la pestaña de moza, enviar una bebida — **no aparece en cocina**
3. Señalar el beep de audio (si el volumen está activo)

**Punto clave:**
> *"La tablet de cocina nunca se apaga. Usa la API de Wake Lock del navegador para mantenerse encendida aunque pase horas sin tocarla. Y solo muestra lo que realmente tiene que preparar — la cocina no ve bebidas."*

---

## Bloque 5 — Delivery (pedido a domicilio)

> *"Para los pedidos que llega por teléfono o WhatsApp."*

**Pasos:**
1. Desde la grilla de mesas, tocar el botón de delivery (ícono de moto)
2. Completar los datos del cliente: nombre, teléfono, dirección
3. Agregar ítems al pedido
4. Mostrar el botón de WhatsApp → genera un mensaje pre-formateado para el cadete
5. El pedido aparece en cocina igual que uno de mesa

---

## Bloque 6 — Reportes y cierre de caja

> *"Al final del día, todo queda registrado."*

**Pasos:**
1. Ingresar como Lescano o Caja → ir a Reportes
2. Mostrar el resumen del día:
   - Total de ventas
   - Desglose por método de pago
   - Mesas cerradas y promedio por cubierto
3. Bajar hasta el historial de mesas cerradas
4. Mostrar el top de productos del día
5. Señalar el botón "Exportar CSV"
6. Mostrar el botón "Cierre de caja"

**Punto clave:**
> *"Con un toque exporta todo a Excel. Ideal para la contadora."*

---

## Bloque 7 — Panel de administración

> *"El dueño tiene control total, sin necesitar ayuda técnica."*

### 7.1 Gestión de usuarios

1. Ingresar como Lescano → ir a Admin
2. Tab "Usuarios" — mostrar la lista de personal
3. Tocar "+ Nuevo" → completar el formulario → crear
4. El nuevo usuario aparece inmediatamente en la lista
5. Mostrar cómo desactivar un usuario (el historial se conserva)
6. Mostrar cómo cambiar la contraseña (🔑)

### 7.2 Edición de precios en tiempo real

> *"Acá está el punto más importante. Sin código, sin deploy."*

1. Tab "Menú" — mostrar la lista completa de ítems
2. Tocar el precio de "Elmer Fudd Solo" (por ejemplo: `$8.000`)
3. Cambiarlo a `$9.000`
4. Salir del campo (tocar afuera o presionar Tab)
5. Ver el toast "Precio actualizado ✓"
6. **Abrir la carta digital en otra pestaña** — recargar — el precio ya es `$9.000`

**Punto clave:**
> *"Antes de este sistema, cambiar un precio requería editar código y esperar 2 minutos de deploy. Ahora lo hace el dueño en 5 segundos desde el celular."*

### 7.3 Configuración

1. Tab "Configuración"
2. Mostrar el campo de costo de envío
3. Cambiarlo → guardar → explicar que se suma automáticamente a todos los pedidos de delivery

---

## Bloque 8 — Arquitectura (para audiencia técnica)

> *Opcional — saltearlo si la audiencia no es técnica.*

```
Cliente (Vue 3 + TypeScript)
    ↓
GitHub Pages (estático, build automático en cada push a master)
    ↓
Supabase Cloud
    ├── PostgreSQL 17 — datos, RLS por rol
    ├── GoTrue Auth — login con email @lescanos.local
    ├── PostgREST — API REST automática
    ├── Realtime — WebSockets para cocina y notificaciones
    └── Edge Functions (Deno) — admin-users (crea/elimina usuarios con service_role)
```

**Seguridad:**
- RLS en todas las tablas — cada rol ve solo lo que le corresponde
- La moza no puede acceder a los datos de otra moza
- Solo el dueño puede modificar precios, usuarios y configuración
- La service role key nunca llega al cliente — solo la usa la Edge Function

**Resiliencia:**
- El menú se cachea en `localStorage` — si Supabase no responde, el cliente igual ve la carta
- El sistema funciona offline para lectura (la carta digital)

---

## Preguntas frecuentes durante una demo

**¿Funciona en cualquier celular?**
Sí. Es una Progressive Web App. Funciona en Chrome, Safari, Firefox. No requiere instalación.

**¿Qué pasa si se corta internet en el local?**
La carta digital sigue funcionando desde el cache. Las operaciones de mesas requieren conexión, pero los datos no se pierden — cuando vuelve internet todo se sincroniza.

**¿Se puede agregar más personal?**
Sí, desde el panel admin, en segundos, sin tocar código.

**¿Cuánto cuesta Supabase?**
El plan gratuito cubre ampliamente este caso de uso: 500MB de DB, 2 proyectos, usuarios ilimitados. Para un restaurante como Lescano's, el costo es $0/mes.

**¿Se puede adaptar a otro restaurante?**
Sí. Los cambios necesarios son: colores/branding, menú inicial, número de mesas y número de WhatsApp. Todo configurable sin tocar la lógica.

**¿Puedo ver el historial de días anteriores?**
Sí. En Reportes, el navegador de fechas permite ver cualquier día anterior con todos los detalles.

**¿Se puede usar en simultáneo desde varios dispositivos?**
Sí, es el caso de uso normal. Moza con su tablet, cocina con su tablet, caja con su celular — todo sincronizado en tiempo real.
