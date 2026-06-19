-- Seguridad para tracking de entrega (feature/entrega-items)
--
-- PROBLEMA: faltaba GRANT UPDATE en pedido_items y política RLS para UPDATE.
-- Sin esto, marcarEntregado() fallaría con 403 en producción.
--
-- RESTRICCIÓN: cocina NO puede marcar ítems como entregados.
-- Solo puede: moza (sus propias mesas), caja y dueño.

-- Grant a nivel de columna: solo entregado_qty, no el resto del row
GRANT UPDATE (entregado_qty) ON pedido_items TO authenticated;

-- Política RLS para UPDATE
DROP POLICY IF EXISTS pedido_items_update ON pedido_items;

CREATE POLICY pedido_items_update ON pedido_items
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1
      FROM sesiones s
      JOIN perfiles p ON p.id = auth.uid()
      WHERE s.id = pedido_items.sesion_id
        AND p.activo = true
        AND (
          -- Moza: solo sus propias mesas
          (p.rol = 'moza'  AND s.moza_id = auth.uid())
          OR
          -- Caja y dueño: cualquier mesa
          p.rol IN ('caja', 'dueno')
          -- cocina queda excluida implícitamente
        )
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM sesiones s
      JOIN perfiles p ON p.id = auth.uid()
      WHERE s.id = pedido_items.sesion_id
        AND p.activo = true
        AND (
          (p.rol = 'moza'  AND s.moza_id = auth.uid())
          OR p.rol IN ('caja', 'dueno')
        )
    )
  );
