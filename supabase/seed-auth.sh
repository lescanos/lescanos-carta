#!/bin/bash
# Seed completo del entorno local: crea usuarios en GoTrue + perfiles en DB.
# Ejecutar DESPUÉS de: npx supabase db reset
#
# Uso:  bash supabase/seed-auth.sh

set -e

SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU"
API="http://127.0.0.1:54321/auth/v1/admin/users"
PASS="test1234"

create_user() {
  local UUID=$1 EMAIL=$2
  RESULT=$(curl -s -X POST "$API" \
    -H "apikey: $SERVICE_KEY" \
    -H "Authorization: Bearer $SERVICE_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"id\":\"$UUID\",\"email\":\"$EMAIL\",\"password\":\"$PASS\",\"email_confirm\":true}")
  if echo "$RESULT" | grep -q '"email"'; then
    echo "✓ $EMAIL"
  else
    # Ya existe — actualizar contraseña
    curl -s -X PUT "$API/$UUID" \
      -H "apikey: $SERVICE_KEY" \
      -H "Authorization: Bearer $SERVICE_KEY" \
      -H "Content-Type: application/json" \
      -d "{\"password\":\"$PASS\"}" > /dev/null
    echo "~ $EMAIL (ya existía, contraseña actualizada)"
  fi
}

echo "=== Paso 1: Usuarios en GoTrue (contraseña: $PASS) ==="
create_user "aaaaaaaa-0000-0000-0000-000000000001" "dueno@lescanos.local"
create_user "aaaaaaaa-0000-0000-0000-000000000002" "moza1@lescanos.local"
create_user "aaaaaaaa-0000-0000-0000-000000000003" "cocina@lescanos.local"
create_user "aaaaaaaa-0000-0000-0000-000000000004" "caja@lescanos.local"

echo ""
echo "=== Paso 2: Perfiles en la DB ==="
docker exec -i supabase_db_lescanos-carta psql -U postgres << 'SQLEOF'
INSERT INTO perfiles (id, nombre, login_key, rol, emoji) VALUES
  ('aaaaaaaa-0000-0000-0000-000000000001', 'Lescano', 'dueno',  'dueno',  '👑'),
  ('aaaaaaaa-0000-0000-0000-000000000002', 'María',   'moza1',  'moza',   '🧑‍💼'),
  ('aaaaaaaa-0000-0000-0000-000000000003', 'Cocina',  'cocina', 'cocina', '🍳'),
  ('aaaaaaaa-0000-0000-0000-000000000004', 'Caja',    'caja',   'caja',   '💵')
ON CONFLICT (id) DO UPDATE
  SET nombre = EXCLUDED.nombre,
      login_key = EXCLUDED.login_key,
      rol = EXCLUDED.rol,
      emoji = EXCLUDED.emoji;
SELECT '✓ ' || nombre || ' (' || rol || ')' as perfil FROM perfiles ORDER BY nombre;
SQLEOF

echo ""
echo "Listo. Ingresá con cualquier usuario usando la contraseña: $PASS"
