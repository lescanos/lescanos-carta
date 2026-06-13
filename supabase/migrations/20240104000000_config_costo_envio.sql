-- Precio de envío a domicilio (configurable por el dueño)
insert into config (clave, valor)
values ('costo_envio', '0')
on conflict (clave) do nothing;
