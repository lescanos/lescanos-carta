-- Permite lectura pública de claves de marca (brand_*) sin autenticación.
-- Necesario para que la página de login pueda cargar el emailDomain correcto
-- antes de que el usuario se autentique.
create policy "config_brand_anon_select" on config
  for select to anon using (clave like 'brand_%');
