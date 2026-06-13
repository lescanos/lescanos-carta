-- Tablas para gestión de menú desde el panel del dueño
-- Permite editar precios sin tocar código ni hacer deploys

create table menu_secciones (
  id               uuid  primary key default gen_random_uuid(),
  pagina           int   not null,
  pagina_titulo    text  not null default '',
  pagina_tipo      text  not null default 'regular',  -- 'regular' | 'promos'
  pagina_subtitulo text,
  seccion_orden    int   not null default 0,
  emoji            text,
  titulo           text  not null default '',
  nota             text  default '',
  columnas         text[]
);

create table menu_items (
  id           uuid  primary key default gen_random_uuid(),
  seccion_id   uuid  not null references menu_secciones(id) on delete cascade,
  item_orden   int   not null default 0,
  nombre       text  not null,
  descripcion  text  default '',
  precios      text[] not null default '{}'
);

-- RLS
alter table menu_secciones enable row level security;
alter table menu_items     enable row level security;

-- Lectura pública (la carta digital es pública, sin login)
create policy "menu_secciones_select" on menu_secciones for select using (true);
create policy "menu_items_select"     on menu_items     for select using (true);

-- Escritura solo para el dueño
create policy "menu_secciones_write" on menu_secciones
  for all
  using (exists (
    select 1 from perfiles p
    where p.id = auth.uid() and p.rol = 'dueno' and p.activo = true
  ))
  with check (exists (
    select 1 from perfiles p
    where p.id = auth.uid() and p.rol = 'dueno' and p.activo = true
  ));

create policy "menu_items_write" on menu_items
  for all
  using (exists (
    select 1 from perfiles p
    where p.id = auth.uid() and p.rol = 'dueno' and p.activo = true
  ))
  with check (exists (
    select 1 from perfiles p
    where p.id = auth.uid() and p.rol = 'dueno' and p.activo = true
  ));

-- GRANTs
grant select                       on menu_secciones to anon, authenticated;
grant insert, update, delete       on menu_secciones to authenticated;
grant all                          on menu_secciones to service_role;

grant select                       on menu_items to anon, authenticated;
grant insert, update, delete       on menu_items to authenticated;
grant all                          on menu_items to service_role;
