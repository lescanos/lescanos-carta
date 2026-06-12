#!/bin/bash
# Crear usuarios de prueba en GoTrue (auth de Supabase local).
# Ejecutar DESPUÉS de: npx supabase db reset
#
# Uso:  bash supabase/seed-auth.sh

SERVICE_KEY="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU"
API="http://127.0.0.1:54321/auth/v1/admin/users"
PASS="test1234"

create_user() {
  local UUID=$1 EMAIL=$2
  curl -s -X POST "$API" \
    -H "apikey: $SERVICE_KEY" \
    -H "Authorization: Bearer $SERVICE_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"id\":\"$UUID\",\"email\":\"$EMAIL\",\"password\":\"$PASS\",\"email_confirm\":true}" \
    | grep -q '"email"' && echo "✓ $EMAIL" || echo "✗ $EMAIL (puede que ya exista)"
}

echo "Creando usuarios de prueba (contraseña: $PASS)..."
create_user "aaaaaaaa-0000-0000-0000-000000000001" "dueno@lescanos.local"
create_user "aaaaaaaa-0000-0000-0000-000000000002" "moza1@lescanos.local"
create_user "aaaaaaaa-0000-0000-0000-000000000003" "cocina@lescanos.local"
create_user "aaaaaaaa-0000-0000-0000-000000000004" "caja@lescanos.local"
echo "Listo."
