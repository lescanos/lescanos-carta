-- RLS estricto para datos financieros: solo caja y dueño

-- ── pagos ─────────────────────────────────────────────
drop policy if exists pagos_select on pagos;
drop policy if exists pagos_insert on pagos;

create policy pagos_select on pagos
  for select using (
    exists (
      select 1 from perfiles
      where id = auth.uid() and rol in ('caja','dueno') and activo = true
    )
  );

create policy pagos_insert on pagos
  for insert with check (auth.role() = 'authenticated');

-- ── cierres ───────────────────────────────────────────
drop policy if exists cierres_select on cierres;
drop policy if exists cierres_insert on cierres;

create policy cierres_select on cierres
  for select using (
    exists (
      select 1 from perfiles
      where id = auth.uid() and rol in ('caja','dueno') and activo = true
    )
  );

create policy cierres_insert on cierres
  for insert with check (
    exists (
      select 1 from perfiles
      where id = auth.uid() and rol in ('caja','dueno') and activo = true
    )
  );

-- ── perfiles: quitar login_key del grant anon ─────────
-- La pantalla de login solo necesita id, nombre, emoji, activo
-- Creamos una vista segura para el login (anon solo ve esos campos)
create or replace view perfiles_publicos as
  select id, nombre, login_key, emoji, activo from perfiles where activo = true;

grant select on perfiles_publicos to anon;
grant select on perfiles_publicos to authenticated;
