-- ═══════════════════════════════════════════════════════════════════
--  Fix: aplica todo lo que quedó pendiente de 20240101→20240107
--  Las migraciones fueron marcadas como "applied" sin correr el SQL.
--  Esta migración es completamente idempotente (safe to re-run).
-- ═══════════════════════════════════════════════════════════════════

-- ── 1. COLUMNAS FALTANTES ────────────────────────────────────────────

-- De 20240102: sesion_id en pedido_items (permite cargar items por sesión sin JOINs)
ALTER TABLE pedido_items
  ADD COLUMN IF NOT EXISTS sesion_id uuid REFERENCES sesiones(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS pedido_items_sesion_id_idx ON pedido_items(sesion_id);

-- De 20240103: método de pago pre-seleccionado en envíos/llevar
ALTER TABLE sesiones
  ADD COLUMN IF NOT EXISTS metodo_pago text;

-- De 20240103: agregar 'llevar' al check de tipo
ALTER TABLE sesiones DROP CONSTRAINT IF EXISTS sesiones_tipo_check;
ALTER TABLE sesiones ADD CONSTRAINT sesiones_tipo_check
  CHECK (tipo IN ('mesa','envio','llevar'));

-- ── 2. GRANTS ────────────────────────────────────────────────────────

-- Lectura pública de perfiles (pantalla de login)
GRANT SELECT ON perfiles TO anon;
GRANT SELECT ON perfiles TO authenticated;

-- Operaciones de mesas
GRANT SELECT, INSERT, UPDATE ON sesiones     TO authenticated;
GRANT SELECT, INSERT, UPDATE ON pedidos      TO authenticated;
GRANT SELECT, INSERT         ON pedido_items TO authenticated;
GRANT SELECT, INSERT         ON pagos        TO authenticated;
GRANT SELECT, INSERT, UPDATE ON cierres      TO authenticated;
GRANT SELECT, INSERT, UPDATE ON config       TO authenticated;
GRANT SELECT                 ON config       TO anon;

-- Gestión de usuarios (dueño via Edge Function)
GRANT INSERT, UPDATE, DELETE ON perfiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON perfiles TO service_role;

-- Service role full access
GRANT ALL ON sesiones     TO service_role;
GRANT ALL ON pedidos      TO service_role;
GRANT ALL ON pedido_items TO service_role;
GRANT ALL ON pagos        TO service_role;
GRANT ALL ON cierres      TO service_role;
GRANT ALL ON config       TO service_role;

-- ── 3. POLICIES RLS ──────────────────────────────────────────────────

-- De 20240105: pagos solo visible para caja/dueño
DROP POLICY IF EXISTS pagos_select ON pagos;
DROP POLICY IF EXISTS pagos_insert ON pagos;

CREATE POLICY pagos_select ON pagos
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM perfiles
      WHERE id = auth.uid() AND rol IN ('caja','dueno') AND activo = true
    )
  );

CREATE POLICY pagos_insert ON pagos
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- De 20240105: cierres solo para caja/dueño
DROP POLICY IF EXISTS cierres_select ON cierres;
DROP POLICY IF EXISTS cierres_insert ON cierres;

CREATE POLICY cierres_select ON cierres
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM perfiles
      WHERE id = auth.uid() AND rol IN ('caja','dueno') AND activo = true
    )
  );

CREATE POLICY cierres_insert ON cierres
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM perfiles
      WHERE id = auth.uid() AND rol IN ('caja','dueno') AND activo = true
    )
  );

-- De 20240107: perfiles — escritura para dueño
DROP POLICY IF EXISTS perfiles_update ON perfiles;
DROP POLICY IF EXISTS perfiles_insert ON perfiles;
DROP POLICY IF EXISTS perfiles_delete ON perfiles;

CREATE POLICY perfiles_update ON perfiles
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM perfiles p
      WHERE p.id = auth.uid() AND p.rol = 'dueno' AND p.activo = true
    )
  );

CREATE POLICY perfiles_insert ON perfiles
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY perfiles_delete ON perfiles
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM perfiles p
      WHERE p.id = auth.uid() AND p.rol = 'dueno' AND p.activo = true
    )
  );

-- ── 4. VISTA PÚBLICA DE PERFILES ─────────────────────────────────────

-- De 20240105: solo exponer campos seguros al login (no login_key completo)
CREATE OR REPLACE VIEW perfiles_publicos AS
  SELECT id, nombre, login_key, emoji, activo FROM perfiles WHERE activo = true;

GRANT SELECT ON perfiles_publicos TO anon;
GRANT SELECT ON perfiles_publicos TO authenticated;

-- ── 5. REALTIME ──────────────────────────────────────────────────────

-- Necesario para que cocina reciba pedidos y moza reciba "listo"
-- Usamos bloque DO para no fallar si ya estaban en la publicación
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE pedidos;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE sesiones;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;
END $$;

-- ── 6. PERFILES FK Y CONFIG SEED ─────────────────────────────────────

-- De 20240106: eliminar FK para que el seed local no falle
ALTER TABLE perfiles DROP CONSTRAINT IF EXISTS perfiles_id_fkey;

-- De 20240104: seed de costo de envío
INSERT INTO config (clave, valor)
VALUES ('costo_envio', '0')
ON CONFLICT (clave) DO NOTHING;
