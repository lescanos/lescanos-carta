-- Tracking de entrega ítem por ítem por la moza
-- entregado_qty: cuántas unidades de ese ítem ya fueron entregadas a la mesa

ALTER TABLE pedido_items
  ADD COLUMN IF NOT EXISTS entregado_qty integer NOT NULL DEFAULT 0;

-- Agregar pedido_items a realtime para que el estado de entrega
-- se sincronice entre dispositivos (moza, caja, dueño) en tiempo real
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE pedido_items;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
END $$;
