-- ═══════════════════════════════════════════════════════════════════
--  Seed de desarrollo — usuarios y datos de prueba
--  Se ejecuta automáticamente con: npx supabase db reset
-- ═══════════════════════════════════════════════════════════════════

-- Crear usuarios de prueba en auth.users (Supabase local)
-- Contraseña para todos: "test1234"
insert into auth.users (
  id, email, encrypted_password, email_confirmed_at,
  created_at, updated_at, raw_app_meta_data, raw_user_meta_data,
  aud, role
) values
  (
    'aaaaaaaa-0000-0000-0000-000000000001',
    'dueno@lescanos.local',
    crypt('test1234', gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}',
    '{}',
    'authenticated', 'authenticated'
  ),
  (
    'aaaaaaaa-0000-0000-0000-000000000002',
    'moza1@lescanos.local',
    crypt('test1234', gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}',
    '{}',
    'authenticated', 'authenticated'
  ),
  (
    'aaaaaaaa-0000-0000-0000-000000000003',
    'cocina@lescanos.local',
    crypt('test1234', gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}',
    '{}',
    'authenticated', 'authenticated'
  ),
  (
    'aaaaaaaa-0000-0000-0000-000000000004',
    'caja@lescanos.local',
    crypt('test1234', gen_salt('bf')),
    now(), now(), now(),
    '{"provider":"email","providers":["email"]}',
    '{}',
    'authenticated', 'authenticated'
  )
on conflict (id) do nothing;

-- Perfiles del personal
insert into perfiles (id, nombre, login_key, rol, emoji) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Lescano', 'dueno',  'dueno',  '👑'),
  ('aaaaaaaa-0000-0000-0000-000000000002', 'María',   'moza1',  'moza',   '🧑‍💼'),
  ('aaaaaaaa-0000-0000-0000-000000000003', 'Cocina',  'cocina', 'cocina', '🍳'),
  ('aaaaaaaa-0000-0000-0000-000000000004', 'Caja',    'caja',   'caja',   '💵')
on conflict (id) do nothing;
