alter table pedido_items
  add column if not exists cancelado boolean not null default false;
