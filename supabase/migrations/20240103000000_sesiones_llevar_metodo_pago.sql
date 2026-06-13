-- Agrega soporte para múltiples pedidos "para llevar" y método de pago en sesiones

-- 1. Ampliar el CHECK de tipo para incluir 'llevar'
alter table sesiones drop constraint if exists sesiones_tipo_check;
alter table sesiones add constraint sesiones_tipo_check
  check (tipo in ('mesa','envio','llevar'));

-- 2. Columna para guardar el método de pago acordado al crear el envío/llevar
alter table sesiones
  add column if not exists metodo_pago text;
