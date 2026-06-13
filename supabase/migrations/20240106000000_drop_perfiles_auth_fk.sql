-- Eliminar FK de perfiles.id → auth.users
-- El seed falla al hacer db reset porque auth.users queda vacío.
-- La relación se mantiene a nivel aplicación (auth.uid() = perfiles.id).
alter table perfiles drop constraint if exists perfiles_id_fkey;
