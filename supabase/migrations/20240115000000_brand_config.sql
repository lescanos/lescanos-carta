-- ── BRAND CONFIG ─────────────────────────────────────────────────────────────
-- Claves de marca configurables sin tocar código.
-- Cada cliente tiene sus propios valores en su instancia de Supabase.

insert into config (clave, valor) values
  ('brand_nombre',              'Lescano''s')       on conflict (clave) do nothing;
insert into config (clave, valor) values
  ('brand_subtitulo',           'FAST FOOD')        on conflict (clave) do nothing;
insert into config (clave, valor) values
  ('brand_email_domain',        'lescanos.local')   on conflict (clave) do nothing;
insert into config (clave, valor) values
  ('brand_contacto_direccion',  'Oroño 5729, Rosario') on conflict (clave) do nothing;
insert into config (clave, valor) values
  ('brand_contacto_telefono',   '341 549-4790')     on conflict (clave) do nothing;
insert into config (clave, valor) values
  ('brand_contacto_instagram',  '@lescanos_oficial') on conflict (clave) do nothing;
insert into config (clave, valor) values
  ('brand_contacto_facebook',   'Lescanos Oficial') on conflict (clave) do nothing;
