-- Allow 'barra' as a pedido tipo so beverages bypass the kitchen
ALTER TABLE pedidos DROP CONSTRAINT IF EXISTS pedidos_tipo_check;
ALTER TABLE pedidos ADD CONSTRAINT pedidos_tipo_check
  CHECK (tipo IN ('pedido', 'cambio', 'cancelacion', 'barra'));

-- Add va_a_cocina flag so each section can declare whether it routes to kitchen
ALTER TABLE menu_secciones
  ADD COLUMN IF NOT EXISTS va_a_cocina boolean NOT NULL DEFAULT true;

-- Bebidas live at the bar — no need to notify cocina
UPDATE menu_secciones
SET va_a_cocina = false
WHERE titulo IN ('BEBIDAS SIN ALCOHOL', 'CERVEZAS', 'TRAGOS');
