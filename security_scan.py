"""
Lescano's — Security Scanner
Corre: python security_scan.py
Requiere: pip install httpx

Checks:
  1. Supabase RLS audit — intenta acceder a datos como anónimo y como moza cruzada
  2. Secrets leak — escanea el HTML publicado buscando keys expuestas
  3. XSS audit — prueba inputs de notas con payloads comunes
"""

import asyncio
import json
import re
import sys
from pathlib import Path

try:
    import httpx
except ImportError:
    print("ERROR: pip install httpx")
    sys.exit(1)

# ─── CONFIG ───────────────────────────────────────────────────────────────────
SB_URL     = "https://hfayvobhkkkdrijzsmtk.supabase.co"
SB_ANON    = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhmYXl2b2Joa2trZHJpanpzbXRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA4Njg2NTgsImV4cCI6MjA5NjQ0NDY1OH0.baQL05XahRraU88bmTuni1Uh0rBN9IqbET98DM_g4Os"

# URL del sitio publicado en GitHub Pages
SITE_URL   = "https://lescanos.github.io/lescanos-carta"

# Credenciales de prueba (mozas reales para el test cruzado)
# Completar con login_key y contraseña de DOS mozas distintas
MOZA_A     = {"login_key": "moza1", "password": "COMPLETAR"}   # moza que inicia el test
MOZA_B     = {"login_key": "moza2", "password": "COMPLETAR"}   # moza cuyas mesas intenta leer moza_a

TABLES     = ["sesiones", "pedidos", "pedido_items", "pagos", "cierres", "config", "perfiles"]

PAGES      = ["index.html", "table-service.html", "kitchen.html", "reports.html", "login.html"]

XSS_PAYLOADS = [
    "<script>alert(1)</script>",
    "<img src=x onerror=alert(1)>",
    "javascript:alert(1)",
    "'><svg onload=alert(1)>",
    "<iframe src=javascript:alert(1)>",
    "{{7*7}}",              # template injection
    "${7*7}",               # JS template literal injection
]

# ─── HELPERS ──────────────────────────────────────────────────────────────────
PASS  = "\033[92m✓\033[0m"
FAIL  = "\033[91m✗\033[0m"
WARN  = "\033[93m⚠\033[0m"
INFO  = "\033[94m·\033[0m"

findings = []

def ok(msg):   print(f"  {PASS} {msg}")
def fail(msg): print(f"  {FAIL} {msg}"); findings.append(msg)
def warn(msg): print(f"  {WARN} {msg}"); findings.append(f"[WARN] {msg}")
def info(msg): print(f"  {INFO} {msg}")

def sb_headers(token=None):
    h = {"apikey": SB_ANON, "Content-Type": "application/json"}
    if token:
        h["Authorization"] = f"Bearer {token}"
    else:
        h["Authorization"] = f"Bearer {SB_ANON}"
    return h

async def sb_get(client, table, token=None, params="select=*&limit=5"):
    url = f"{SB_URL}/rest/v1/{table}?{params}"
    r = await client.get(url, headers=sb_headers(token))
    return r.status_code, r.json() if r.content else []

async def sb_login(client, login_key, password):
    email = f"{login_key}@lescanos.local"
    r = await client.post(
        f"{SB_URL}/auth/v1/token?grant_type=password",
        headers={"apikey": SB_ANON, "Content-Type": "application/json"},
        json={"email": email, "password": password},
    )
    if r.status_code == 200:
        return r.json().get("access_token")
    return None

async def sb_insert(client, table, payload, token=None):
    r = await client.post(
        f"{SB_URL}/rest/v1/{table}",
        headers={**sb_headers(token), "Prefer": "return=minimal"},
        json=payload,
    )
    return r.status_code

# ─── CHECK 1: RLS AUDIT ───────────────────────────────────────────────────────
async def check_rls(client):
    print("\n── 1. SUPABASE RLS AUDIT ─────────────────────────────────────────")

    # 1a. Acceso anónimo (sin JWT) a cada tabla
    print("\n  [1a] Lectura como usuario anónimo (sin autenticación):")
    for table in TABLES:
        code, data = await sb_get(client, table)
        rows = len(data) if isinstance(data, list) else 0
        if code == 200 and rows > 0:
            fail(f"{table}: anónimo puede leer {rows} filas — RLS permisiva")
        elif code == 200 and rows == 0:
            ok(f"{table}: sin filas visibles para anónimo (puede ser RLS o tabla vacía)")
        elif code in (401, 403):
            ok(f"{table}: acceso anónimo bloqueado ({code})")
        else:
            warn(f"{table}: respuesta inesperada {code} — {data}")

    # 1b. Escritura anónima
    print("\n  [1b] Escritura como usuario anónimo:")
    code = await sb_insert(client, "sesiones", {"mesa": "mesa_99", "estado": "abierta"})
    if code in (201, 200):
        fail("sesiones: anónimo pudo insertar una sesión — RLS insert permisiva")
    elif code in (401, 403):
        ok(f"sesiones: inserción anónima bloqueada ({code})")
    else:
        info(f"sesiones: insert anónimo → {code}")

    # 1c. Cruce entre mozas (si hay credenciales configuradas)
    if "COMPLETAR" in [MOZA_A["password"], MOZA_B["password"]]:
        warn("Skipping cross-moza test — completá MOZA_A y MOZA_B en el script")
        return

    print("\n  [1c] Acceso cruzado entre mozas:")
    token_a = await sb_login(client, MOZA_A["login_key"], MOZA_A["password"])
    if not token_a:
        warn(f"No se pudo loguear como moza_a ({MOZA_A['login_key']}@lescanos.local) — verificá credenciales")
        return

    token_b = await sb_login(client, MOZA_B["login_key"], MOZA_B["password"])
    if not token_b:
        warn(f"No se pudo loguear como moza_b ({MOZA_B['login_key']}@lescanos.local) — verificá credenciales")
        return

    # moza_a lee sesiones — ¿ve las de moza_b?
    code_a, sessions_a = await sb_get(client, "sesiones", token_a)
    code_b, sessions_b = await sb_get(client, "sesiones", token_b)

    ids_a = {s.get("id") for s in sessions_a} if isinstance(sessions_a, list) else set()
    ids_b = {s.get("id") for s in sessions_b} if isinstance(sessions_b, list) else set()
    cross = ids_a & ids_b

    if cross:
        warn(f"sesiones: moza_a ve {len(cross)} sesion(es) también visibles para moza_b — revisar si es intencional (mesas abiertas vs cerradas)")
    else:
        ok("sesiones: cada moza ve solo sus propias sesiones")

    # moza_a lee pagos — debería ver solo los suyos
    code_p, pagos_a = await sb_get(client, "pagos", token_a)
    if code_p in (401, 403) or (isinstance(pagos_a, list) and len(pagos_a) == 0):
        ok(f"pagos: moza_a no puede leer pagos ajenos ({code_p})")
    elif isinstance(pagos_a, list) and len(pagos_a) > 0:
        warn(f"pagos: moza_a ve {len(pagos_a)} pago(s) — verificar si corresponden solo a sus sesiones")

    # moza_a intenta leer cierres
    code_c, _ = await sb_get(client, "cierres", token_a)
    if code_c in (401, 403):
        ok("cierres: moza no tiene acceso")
    else:
        fail("cierres: moza puede leer datos del cierre de caja — datos financieros expuestos")

    # moza_a intenta leer config
    code_cfg, cfg = await sb_get(client, "config", token_a)
    if code_cfg == 200 and isinstance(cfg, list) and len(cfg) > 0:
        ok(f"config: moza puede leer config ({len(cfg)} entradas) — intencional, solo num_mesas")
    elif code_cfg in (401, 403):
        info("config: moza no puede leer config")

# ─── CHECK 2: SECRETS LEAK ────────────────────────────────────────────────────
async def check_secrets(client):
    print("\n── 2. SECRETS LEAK EN HTML PUBLICADO ────────────────────────────────")

    # Patterns que NO deberían aparecer en el HTML público
    # La anon key es pública por diseño en Supabase — lo que buscamos es tokens de acceso elevado
    DANGER_PATTERNS = [
        (r"service_role", "service_role key detectada — acceso total a la DB, NUNCA debe estar en el frontend"),
        (r"ghp_[A-Za-z0-9]{36}", "GitHub PAT clásico expuesto"),
        (r"github_pat_[A-Za-z0-9_]{82}", "GitHub PAT fine-grained expuesto"),
        (r"sk-[A-Za-z0-9]{48}", "OpenAI API key expuesta"),
        (r"ADMIN_PWD|__ADMIN_PWD__", "Placeholder de contraseña sin reemplazar"),
        (r"__NUM_MESAS__|__WA_NUMBER__|__MENU_TOKEN__", "Placeholder de secret sin reemplazar"),
        (r"eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+", "JWT encontrado (verificar que es solo el anon key)"),
    ]

    SAFE_JWTS = {SB_ANON}  # JWTs que son públicos por diseño

    for page in PAGES:
        url = f"{SITE_URL}/{page}"
        try:
            r = await client.get(url, follow_redirects=True)
        except Exception as e:
            info(f"{page}: no se pudo descargar ({e})")
            continue

        if r.status_code != 200:
            info(f"{page}: HTTP {r.status_code} — saltando")
            continue

        content = r.text
        print(f"\n  {page}:")

        for pattern, description in DANGER_PATTERNS:
            matches = re.findall(pattern, content)
            if not matches:
                continue

            # Filtrar JWTs conocidos como seguros
            if "JWT" in description:
                real_matches = [m for m in matches if m not in SAFE_JWTS]
                if not real_matches:
                    ok("JWT: solo el anon key de Supabase (público por diseño)")
                    continue
                matches = real_matches

            fail(f"{description}: {matches[0][:60]}...")

        # Buscar scripts externos no esperados (posible supply chain)
        ext_scripts = re.findall(r'<script[^>]+src=["\']([^"\']+)["\']', content)
        expected_domains = ["fonts.googleapis.com", "cdn.jsdelivr.net"]
        for src in ext_scripts:
            if not any(d in src for d in expected_domains):
                warn(f"Script externo inesperado: {src}")

# ─── CHECK 3: XSS AUDIT ───────────────────────────────────────────────────────
async def check_xss(client):
    print("\n── 3. XSS AUDIT — INPUTS EN SUPABASE ───────────────────────────────")
    print("  (requiere una sesión válida para insertar — usar token de moza)")

    if "COMPLETAR" in [MOZA_A["password"]]:
        warn("Skipping XSS insert test — completá MOZA_A en el script")
        _check_xss_local()
        return

    token = await sb_login(client, MOZA_A["login_key"], MOZA_A["password"])
    if not token:
        warn("No se pudo obtener token para XSS test — saltando inserción")
        _check_xss_local()
        return

    # Buscar una sesión abierta de esta moza para insertar en ella
    code, sesiones = await sb_get(client, "sesiones", token,
        params="select=id&estado=eq.abierta&limit=1")

    if not sesiones or not isinstance(sesiones, list) or len(sesiones) == 0:
        info("No hay sesiones abiertas para esta moza — creando una de test")
        code_s = await sb_insert(client, "sesiones",
            {"mesa": "mesa_test_xss", "estado": "abierta"}, token)
        if code_s not in (200, 201):
            warn(f"No se pudo crear sesión de test ({code_s}) — saltando XSS insert")
            _check_xss_local()
            return
        _, sesiones = await sb_get(client, "sesiones", token,
            params="select=id&mesa=eq.mesa_test_xss&limit=1")

    if not sesiones or not isinstance(sesiones, list):
        warn("Sin sesión disponible para XSS test")
        _check_xss_local()
        return

    sesion_id = sesiones[0]["id"]
    print(f"\n  Insertando payloads XSS en pedido_items (sesión {sesion_id[:8]}…):")

    for payload in XSS_PAYLOADS:
        # Intentar guardar el payload como nota de un item
        code_p = await sb_insert(client, "pedidos", {"sesion_id": sesion_id}, token)
        if code_p not in (200, 201):
            info(f"  No se pudo insertar pedido (code {code_p}) — posiblemente bloqueado por RLS")
            break

        # Buscar el pedido recién creado
        _, pedidos = await sb_get(client, "pedidos", token,
            params=f"select=id&sesion_id=eq.{sesion_id}&order=created_at.desc&limit=1")

        if not pedidos or not isinstance(pedidos, list):
            info("  Sin pedido para insertar items")
            break

        pedido_id = pedidos[0]["id"]
        code_i = await sb_insert(client, "pedido_items", {
            "pedido_id": pedido_id,
            "sesion_id": sesion_id,
            "nombre":    "Item test",
            "precio":    0,
            "qty":       1,
            "nota":      payload,
        }, token)

        if code_i in (200, 201):
            warn(f"Payload guardado en DB: {payload[:50]} — verificar que se escapa al renderizar")
        elif code_i in (401, 403):
            ok(f"Insert rechazado por RLS ({code_i})")
        else:
            info(f"Insert → {code_i} para payload: {payload[:40]}")

    # Limpiar sesión de test
    await client.delete(
        f"{SB_URL}/rest/v1/sesiones?mesa=eq.mesa_test_xss",
        headers={**sb_headers(token), "Prefer": "return=minimal"}
    )

    _check_xss_local()


def _check_xss_local():
    """Escanea los archivos HTML locales buscando innerHTML sin esc()."""
    print("\n  [3b] Análisis estático — innerHTML sin esc() en archivos locales:")

    # Patrones de riesgo: template literal con variable potencialmente user-controlled
    RISKY_VARS = ["nota", "nombre", "moza", "mesa", "titulo", "desc", "seccion"]
    # Encuentra template literals con estas variables sin esc()
    UNESCAPED_PATTERN = re.compile(
        r'\$\{(?!esc\()([^}]*(?:' + '|'.join(RISKY_VARS) + r')[^}]*)\}',
        re.IGNORECASE
    )

    html_files = ["table-service.html", "reports.html", "kitchen.html", "login.html", "index.html"]
    root = Path(__file__).parent

    for fname in html_files:
        fpath = root / fname
        if not fpath.exists():
            continue
        content = fpath.read_text(encoding="utf-8")

        # Solo analizar dentro de innerHTML assignments
        innerHTML_blocks = re.findall(
            r'innerHTML\s*[+=]=?\s*[`\'"].*?(?:;|\n(?=\s*[a-z]))',
            content, re.DOTALL
        )

        hits = []
        for block in innerHTML_blocks:
            for m in UNESCAPED_PATTERN.finditer(block):
                expr = m.group(1).strip()
                # Excluir expresiones que son solo números o condiciones simples
                if not re.match(r'^[\d\s\+\-\*\/\(\)\?\:\.]+$', expr):
                    hits.append(expr[:60])

        if hits:
            warn(f"{fname}: posibles expresiones sin esc() en innerHTML:")
            for h in hits[:5]:
                print(f"      → {h}")
        else:
            ok(f"{fname}: sin expresiones obvias sin esc() en innerHTML")


# ─── RESUMEN FINAL ────────────────────────────────────────────────────────────
def print_summary():
    print("\n" + "═" * 60)
    print("RESUMEN")
    print("═" * 60)
    if not findings:
        print(f"  {PASS} Sin hallazgos críticos.")
    else:
        errors   = [f for f in findings if not f.startswith("[WARN]")]
        warnings = [f for f in findings if f.startswith("[WARN]")]
        if errors:
            print(f"\n  {FAIL} HALLAZGOS ({len(errors)}):")
            for f in errors:
                print(f"     · {f}")
        if warnings:
            print(f"\n  {WARN} ADVERTENCIAS ({len(warnings)}):")
            for w in warnings:
                print(f"     · {w[7:]}")

    print("\n  Para solucionar hallazgos de RLS:")
    print("  → Correr el SQL de políticas en el SQL Editor de Supabase")
    print("  Para hallazgos de XSS:")
    print("  → Asegurarse de que esc() envuelve toda variable en innerHTML")
    print()


async def main():
    print("╔══════════════════════════════════════════════════════════╗")
    print("║        Lescano's — Security Scanner                     ║")
    print("╚══════════════════════════════════════════════════════════╝")
    print(f"  Supabase: {SB_URL}")
    print(f"  Sitio:    {SITE_URL}")

    async with httpx.AsyncClient(timeout=15) as client:
        await check_rls(client)
        await check_secrets(client)
        await check_xss(client)

    print_summary()


if __name__ == "__main__":
    asyncio.run(main())
