# Backlog de mejoras — Lescano's

Priorizado por impacto en operación real. Basado en análisis del sistema actual y comparación con Toast POS / Square for Restaurants.

---

## ✅ En progreso / completado en feature/mejoras

- [x] Carta pública como pantalla inicial
- [x] Login por roles con tiles
- [x] MesasPage completa (mesas + llevar + envíos)
- [x] KitchenPage en tiempo real
- [x] ReportsPage + cierre de caja
- [x] Precios reales desde menu-data.json
- [x] Logout funcionando
- [x] División de cuenta ← en curso
- [x] Gestión de usuarios ← en curso

---

## 🔴 Crítico — bloquea operación si falla

### Modo offline
- Service worker + IndexedDB como cola local
- Sync automático cuando vuelve la conexión
- **Por qué crítico:** si se cae Supabase o el WiFi del local, el sistema queda inutilizable. En hora pico un sábado, eso es catastrófico.
- Comparable: Toast POS usa SQLite local + sync, funciona sin internet indefinidamente.

### Integración con impresora
- Impresora térmica Bluetooth (cualquier ESC/POS) o WiFi
- Alternativa mínima viable: browser print dialog estilizado para 80mm
- **Por qué crítico:** depender 100% de WhatsApp para cocina significa que si WA tiene un problema o el celular de cocina se queda sin batería, los pedidos no llegan.

---

## 🟡 Importante — mejora operación diaria

### Sistema 86 (ítem agotado)
- Botón en KitchenPage para marcar un ítem como "no disponible hoy"
- El ítem aparece tachado/bloqueado en el menú del mozo
- Se resetea al inicio del día o manualmente
- **Impacto:** evita que el mozo venda lo que no hay y tenga que volver a la mesa.

### Modificadores estructurados
- Por categoría, opciones pre-armadas: [Sin cebolla] [Extra queso] [Término: jugoso/a punto/cocido]
- El cocinero los ve como ítems explícitos en la pantalla, no texto libre
- Actualmente: campo de nota libre que se ignora en hora pico
- **Impacto:** reduce errores de preparación, acelera toma de pedidos.

### Contraseñas por usuario
- Hoy todos comparten una contraseña (riesgo de seguridad cuando hay rotación de personal)
- Gestión de usuarios cubre esto ← implementando ahora

---

## 🟢 Mejoras de negocio

### Reportes por turno
- Hoy: reporte por día completo
- Agregar: turno mediodía vs noche, reporte por mozo, hora pico
- Datos ya están en la DB, solo falta la UI

### Panel de promos dinámicas
- Hoy: CartaPage muestra promos hardcodeadas en menu.js
- Permitir al dueño activar/desactivar promos desde el panel
- Que las promos activas aparezcan en el menú del mozo con precio/validación

### Reservas
- Sistema simple: nombre, fecha, hora, cubiertos, mesa asignada
- Vista en MesasPage que muestra qué mesas tienen reserva
- Sin integración externa por ahora

### Historial por cliente (delivery)
- Para envíos a domicilio: guardar historial de pedidos por teléfono
- Autocompletar dirección si ya existe el número
- Vista de "clientes frecuentes"

### Analítica avanzada
- Top 10 ítems más vendidos
- Comparativa semana a semana
- Ticket promedio por mesa vs llevar vs delivery

---

## 🔵 Largo plazo

- Loyalty / puntos (poco relevante para el modelo actual)
- Integración con PedidosYa/Rappi (complejo, fees)
- App nativa (actualmente PWA es suficiente)
- Multi-sucursal
