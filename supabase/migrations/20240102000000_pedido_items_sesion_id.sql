-- Agrega sesion_id a pedido_items para poder cargar los items de una sesión
-- sin hacer JOINs a través de pedidos.

alter table pedido_items
  add column if not exists sesion_id uuid references sesiones(id) on delete cascade;

create index if not exists pedido_items_sesion_id_idx on pedido_items(sesion_id);
