-- ═══════════════════════════════════════════════════════════════════
--  Lescano's — Schema inicial
--  Aplica en orden: tablas, RLS, policies, seed de config
-- ═══════════════════════════════════════════════════════════════════

-- ── EXTENSIONES ─────────────────────────────────────────────────────
create extension if not exists "uuid-ossp";

-- ── PERFILES ────────────────────────────────────────────────────────
create table if not exists perfiles (
  id           uuid primary key references auth.users on delete cascade,
  nombre       text not null,
  login_key    text not null unique,
  rol          text not null check (rol in ('moza','cocina','caja','dueno')),
  emoji        text default '🧑',
  activo       boolean default true,
  created_at   timestamptz default now()
);

alter table perfiles enable row level security;

-- Lectura pública: la pantalla de login necesita los tiles sin estar autenticado
create policy "perfiles_select" on perfiles
  for select using (true);

-- ── SESIONES ────────────────────────────────────────────────────────
create table if not exists sesiones (
  id                  uuid primary key default uuid_generate_v4(),
  mesa                text not null,
  estado              text not null default 'abierta' check (estado in ('abierta','cerrada')),
  cubiertos           int default 1,
  moza_id             uuid references perfiles(id),
  moza_nombre         text,
  tipo                text default 'mesa' check (tipo in ('mesa','envio')),
  cliente_nombre      text,
  cliente_telefono    text,
  cliente_direccion   text,
  cliente_referencia  text,
  created_at          timestamptz default now(),
  closed_at           timestamptz
);

alter table sesiones enable row level security;

-- Todas las sesiones son visibles para usuarios autenticados
create policy "sesiones_select" on sesiones
  for select using (auth.role() = 'authenticated');

create policy "sesiones_insert" on sesiones
  for insert with check (auth.role() = 'authenticated');

create policy "sesiones_update" on sesiones
  for update using (auth.role() = 'authenticated');

-- ── PEDIDOS ─────────────────────────────────────────────────────────
create table if not exists pedidos (
  id          uuid primary key default uuid_generate_v4(),
  sesion_id   uuid not null references sesiones(id) on delete cascade,
  estado      text not null default 'pendiente' check (estado in ('pendiente','listo')),
  tipo        text default 'pedido' check (tipo in ('pedido','cambio','cancelacion')),
  listo_at    timestamptz,
  created_at  timestamptz default now()
);

alter table pedidos enable row level security;

create policy "pedidos_select" on pedidos
  for select using (auth.role() = 'authenticated');

create policy "pedidos_insert" on pedidos
  for insert with check (auth.role() = 'authenticated');

create policy "pedidos_update" on pedidos
  for update using (auth.role() = 'authenticated');

-- Realtime: publicar cambios en pedidos
alter publication supabase_realtime add table pedidos;
alter publication supabase_realtime add table sesiones;

-- ── PEDIDO_ITEMS ────────────────────────────────────────────────────
create table if not exists pedido_items (
  id          uuid primary key default uuid_generate_v4(),
  pedido_id   uuid not null references pedidos(id) on delete cascade,
  nombre      text not null,
  precio      text,
  qty         int default 1,
  nota        text,
  seccion     text,
  pagina      text,
  created_at  timestamptz default now()
);

alter table pedido_items enable row level security;

create policy "pedido_items_select" on pedido_items
  for select using (auth.role() = 'authenticated');

create policy "pedido_items_insert" on pedido_items
  for insert with check (auth.role() = 'authenticated');

-- ── PAGOS ───────────────────────────────────────────────────────────
create table if not exists pagos (
  id          uuid primary key default uuid_generate_v4(),
  sesion_id   uuid not null references sesiones(id) on delete cascade,
  metodo      text not null,
  monto       numeric(10,2),
  created_at  timestamptz default now()
);

alter table pagos enable row level security;

create policy "pagos_select" on pagos
  for select using (auth.role() = 'authenticated');

create policy "pagos_insert" on pagos
  for insert with check (auth.role() = 'authenticated');

-- ── CIERRES ─────────────────────────────────────────────────────────
create table if not exists cierres (
  id            uuid primary key default uuid_generate_v4(),
  fecha         date not null unique,
  efectivo      numeric(10,2) default 0,
  debito        numeric(10,2) default 0,
  credito       numeric(10,2) default 0,
  transferencia numeric(10,2) default 0,
  mercadopago   numeric(10,2) default 0,
  pedidosya     numeric(10,2) default 0,
  total         numeric(10,2) default 0,
  created_at    timestamptz default now()
);

alter table cierres enable row level security;

create policy "cierres_select" on cierres
  for select using (auth.role() = 'authenticated');

create policy "cierres_insert" on cierres
  for insert with check (auth.role() = 'authenticated');

create policy "cierres_update" on cierres
  for update using (auth.role() = 'authenticated');

-- ── CONFIG ──────────────────────────────────────────────────────────
create table if not exists config (
  clave       text primary key,
  valor       text not null,
  updated_at  timestamptz default now()
);

alter table config enable row level security;

create policy "config_select" on config
  for select using (auth.role() = 'authenticated');

create policy "config_upsert" on config
  for all using (auth.role() = 'authenticated');

-- ── SEED CONFIG ─────────────────────────────────────────────────────
insert into config (clave, valor) values ('num_mesas', '8')
  on conflict (clave) do nothing;

-- ── GRANTS ──────────────────────────────────────────────────────────
-- RLS sola no alcanza: el rol también necesita privilegios de tabla.
-- perfiles: lectura pública (login screen la necesita sin auth)
grant select on perfiles to anon;
grant select on perfiles to authenticated;

-- resto: solo authenticated
grant select, insert, update on sesiones      to authenticated;
grant select, insert, update on pedidos       to authenticated;
grant select, insert         on pedido_items  to authenticated;
grant select, insert         on pagos         to authenticated;
grant select, insert, update on cierres       to authenticated;
grant select, insert, update on config        to authenticated;
grant select                 on config        to anon;
