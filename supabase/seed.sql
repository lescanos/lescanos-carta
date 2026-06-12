-- ═══════════════════════════════════════════════════════════════════
--  Seed de desarrollo — datos de prueba
--  Ejecutado automáticamente por: npx supabase db reset
--
--  NOTA: Los usuarios de auth se crean con el script seed-auth.sh
--  porque GoTrue requiere su propia API para hashear contraseñas.
--  Ejecutar después del reset: bash supabase/seed-auth.sh
-- ═══════════════════════════════════════════════════════════════════

-- Perfiles del personal (linked a auth.users creados por seed-auth.sh)
insert into perfiles (id, nombre, login_key, rol, emoji) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Lescano', 'dueno',  'dueno',  '👑'),
  ('aaaaaaaa-0000-0000-0000-000000000002', 'María',   'moza1',  'moza',   '🧑‍💼'),
  ('aaaaaaaa-0000-0000-0000-000000000003', 'Cocina',  'cocina', 'cocina', '🍳'),
  ('aaaaaaaa-0000-0000-0000-000000000004', 'Caja',    'caja',   'caja',   '💵')
on conflict (id) do nothing;
