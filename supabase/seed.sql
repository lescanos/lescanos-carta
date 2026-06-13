-- ═══════════════════════════════════════════════════════════════════
--  Seed de desarrollo
--
--  USUARIOS: correr seed-auth.ps1 después de cada db reset.
--  Crea los usuarios en GoTrue y sincroniza perfiles con los UUIDs reales.
--    powershell.exe -ExecutionPolicy Bypass -File ./supabase/seed-auth.ps1
-- ═══════════════════════════════════════════════════════════════════

-- Configuración por defecto
INSERT INTO config (clave, valor) VALUES
  ('num_mesas','8'),
  ('costo_envio','0')
ON CONFLICT (clave) DO NOTHING;
