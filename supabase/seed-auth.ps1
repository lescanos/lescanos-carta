# Crea usuarios en GoTrue y sincroniza perfiles con los UUIDs reales.
# Uso: powershell.exe -ExecutionPolicy Bypass -File ./supabase/seed-auth.ps1
#
# Correr después de cada: npx supabase db reset

$SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImV4cCI6MTk4MzgxMjk5Nn0.EGIM96RAZx35lJzdJsyH-qQwv8Hdp7fsn3W0YpN81IU"
$AUTH_API  = "http://127.0.0.1:54321/auth/v1/admin/users"
$REST_API  = "http://127.0.0.1:54321/rest/v1/perfiles"

Add-Type -AssemblyName System.Net.Http
$client = New-Object System.Net.Http.HttpClient
$client.DefaultRequestHeaders.Add("apikey",        $SERVICE_KEY)
$client.DefaultRequestHeaders.Add("Authorization", "Bearer $SERVICE_KEY")

# Usuarios: email, login_key, nombre, rol, emoji
$USERS = @(
  @{ email="dueno@lescanos.local";  login_key="dueno";  nombre="Lescano"; rol="dueno";  emoji="👑" }
  @{ email="moza1@lescanos.local";  login_key="moza1";  nombre="María";   rol="moza";   emoji="🧑‍💼" }
  @{ email="cocina@lescanos.local"; login_key="cocina"; nombre="Cocina";  rol="cocina"; emoji="🍳" }
  @{ email="caja@lescanos.local";   login_key="caja";   nombre="Caja";    rol="caja";   emoji="💵" }
)

function Get-OrCreate-User($email, $password) {
  # Intentar crear
  $body    = "{`"email`":`"$email`",`"password`":`"$password`",`"email_confirm`":true}"
  $content = New-Object System.Net.Http.StringContent($body, [System.Text.Encoding]::UTF8, "application/json")
  $resp    = $client.PostAsync($AUTH_API, $content).Result
  $json    = $resp.Content.ReadAsStringAsync().Result | ConvertFrom-Json

  if ([int]$resp.StatusCode -lt 300) {
    Write-Host "CREADO: $email  →  $($json.id)"
    return $json.id
  }

  # Ya existe — buscar su ID
  $listResp = $client.GetAsync("$AUTH_API`?page=1&per_page=50").Result
  $listJson = $listResp.Content.ReadAsStringAsync().Result | ConvertFrom-Json
  $existing = $listJson.users | Where-Object { $_.email -eq $email }
  if ($existing) {
    # Actualizar password
    $upd  = "{`"password`":`"$password`",`"email_confirm`":true}"
    $uc   = New-Object System.Net.Http.StringContent($upd, [System.Text.Encoding]::UTF8, "application/json")
    $req  = New-Object System.Net.Http.HttpRequestMessage("PUT", "$AUTH_API/$($existing.id)")
    $req.Content = $uc
    $r2   = $client.SendAsync($req).Result | Out-Null
    Write-Host "ACTUALIZADO: $email  →  $($existing.id)"
    return $existing.id
  }

  Write-Host "ERROR: no se pudo crear ni encontrar $email"
  return $null
}

function Upsert-Perfil($id, $nombre, $login_key, $rol, $emoji) {
  $body = "{`"id`":`"$id`",`"nombre`":`"$nombre`",`"login_key`":`"$login_key`",`"rol`":`"$rol`",`"emoji`":`"$emoji`",`"activo`":true}"

  # Usar cliente REST con prefer: resolution=merge-duplicates
  $req = New-Object System.Net.Http.HttpRequestMessage("POST", $REST_API)
  $req.Content = New-Object System.Net.Http.StringContent($body, [System.Text.Encoding]::UTF8, "application/json")
  $req.Headers.Add("Prefer", "resolution=merge-duplicates")
  $resp = $client.SendAsync($req).Result

  if ([int]$resp.StatusCode -lt 300) {
    Write-Host "  perfil OK: $nombre ($rol)"
  } else {
    $err = $resp.Content.ReadAsStringAsync().Result
    Write-Host "  perfil ERROR: $err"
  }
}

Write-Host "`nCreando usuarios GoTrue y sincronizando perfiles...`n"

foreach ($u in $USERS) {
  $uid = Get-OrCreate-User $u.email "test1234"
  if ($uid) {
    Upsert-Perfil $uid $u.nombre $u.login_key $u.rol $u.emoji
  }
}

$client.Dispose()
Write-Host "`nListo. Podés iniciar sesión con contraseña: test1234"
