-- Políticas de escritura para perfiles
-- El dueño puede actualizar cualquier perfil (toggle activo, editar, etc.)
-- Usuarios autenticados pueden actualizar su propio perfil (no usado actualmente pero es correcto)

create policy "perfiles_update" on perfiles
  for update using (
    exists (
      select 1 from perfiles p
      where p.id = auth.uid() and p.rol = 'dueno' and p.activo = true
    )
  );

create policy "perfiles_insert" on perfiles
  for insert with check (auth.role() = 'authenticated');

create policy "perfiles_delete" on perfiles
  for delete using (
    exists (
      select 1 from perfiles p
      where p.id = auth.uid() and p.rol = 'dueno' and p.activo = true
    )
  );

grant insert, update, delete on perfiles to authenticated;
grant select, insert, update, delete on perfiles to service_role;
