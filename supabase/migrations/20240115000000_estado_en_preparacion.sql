-- Add 'en_preparacion' state so kitchen can signal they started on an order
ALTER TABLE pedidos DROP CONSTRAINT IF EXISTS pedidos_estado_check;
ALTER TABLE pedidos ADD CONSTRAINT pedidos_estado_check
  CHECK (estado IN ('pendiente', 'en_preparacion', 'listo'));
