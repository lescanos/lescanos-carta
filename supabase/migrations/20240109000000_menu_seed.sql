-- Seed inicial del menú — datos migrados desde menu.js
-- Después de este seed el dueño puede editar precios desde el panel admin sin tocar código

DO $$
DECLARE
  sec_hambur     uuid;
  sec_panchos    uuid;
  sec_milanesas  uuid;
  sec_pizzas     uuid;
  sec_pizzanesas uuid;
  sec_torpedos   uuid;
  sec_carlitos   uuid;
  sec_guarni     uuid;
  sec_bebidas    uuid;
  sec_cervezas   uuid;
  sec_tragos     uuid;
  sec_promos     uuid;
BEGIN

  -- ── PÁGINA 1: Hamburguesas ─────────────────────────────────────────────────
  INSERT INTO menu_secciones (pagina, pagina_titulo, seccion_orden, emoji, titulo, nota, columnas)
  VALUES (1, 'Hamburguesas', 0, '🍔', 'HAMBURGUESAS', 'Con papas y gaseosa de vidrio', ARRAY['Solo','Con papas'])
  RETURNING id INTO sec_hambur;

  INSERT INTO menu_items (seccion_id, item_orden, nombre, descripcion, precios) VALUES
    (sec_hambur, 0, 'Elmer Fudd',  'Mayonesa, medallón 120g, queso, lechuga, tomate',                                          ARRAY['$8.000','$14.000']),
    (sec_hambur, 1, 'Tweety',      'Kétchup, cebolla caramelizada, medallón 120g, panceta, cheddar',                           ARRAY['$10.000','$16.000']),
    (sec_hambur, 2, 'Marvin',      'Mostaza, guacamole, pepinillo, cheddar, dos medallones 120g',                              ARRAY['$12.000','$18.000']),
    (sec_hambur, 3, 'Lescano',     'Mayonesa, dos medallones 120g, jamón, queso, huevo frito, panceta (papas cheddar)',        ARRAY['$14.000','$20.000']),
    (sec_hambur, 4, 'Porky',       'Kétchup, cebolla, dos medallones 120g, cheddar, panceta, bañada en cheddar',              ARRAY['$16.000','$22.000']),
    (sec_hambur, 5, 'Taz',         'Mostaza, tres medallones 120g, cheddar, panceta, cebolla morada, lechuga, tomate',        ARRAY['$15.000','$21.000']);

  -- ── PÁGINA 2: Panchos & Milanesas ─────────────────────────────────────────
  INSERT INTO menu_secciones (pagina, pagina_titulo, seccion_orden, emoji, titulo, nota, columnas)
  VALUES (2, 'Panchos & Milanesas', 0, '🌭', 'PANCHOS', 'Solo o con papas', ARRAY['Solo','Con papas'])
  RETURNING id INTO sec_panchos;

  INSERT INTO menu_items (seccion_id, item_orden, nombre, descripcion, precios) VALUES
    (sec_panchos, 0, 'Lola Bunny', 'Mayonesa, kétchup, papitas',                              ARRAY['$4.500','$8.500']),
    (sec_panchos, 1, 'Bugs Bunny', 'Cebolla caramelizada, papitas, mostaza, queso',           ARRAY['$6.000','$10.000']),
    (sec_panchos, 2, 'Lucas',      'Mayonesa, cheddar, jamón, queso, huevo, papitas',         ARRAY['$8.500','$12.500']);

  INSERT INTO menu_secciones (pagina, pagina_titulo, seccion_orden, emoji, titulo, nota, columnas)
  VALUES (2, 'Panchos & Milanesas', 1, '🥩', 'MILANESAS / SUPREMAS', 'Con papas', ARRAY['Solo','Con papas'])
  RETURNING id INTO sec_milanesas;

  INSERT INTO menu_items (seccion_id, item_orden, nombre, descripcion, precios) VALUES
    (sec_milanesas, 0, 'Abuelita',    'Mayonesa, mostaza, lechuga, tomate',                              ARRAY['$8.000','$12.000']),
    (sec_milanesas, 1, 'San Bigotes', 'Kétchup, cebolla caramelizada, queso, tomate',                   ARRAY['$9.000','$13.000']),
    (sec_milanesas, 2, 'Silvestre',   'Mayonesa, cebolla con ají, jamón, queso, huevo, lechuga, tomate',ARRAY['$10.000','$14.000']),
    (sec_milanesas, 3, 'Lescano',     'Mayonesa, cheddar, huevo, jamón, queso, panceta',                ARRAY['$12.000','$16.000']);

  -- ── PÁGINA 3: Pizzas & Pizzanesas ─────────────────────────────────────────
  INSERT INTO menu_secciones (pagina, pagina_titulo, seccion_orden, emoji, titulo, nota, columnas)
  VALUES (3, 'Pizzas & Pizzanesas', 0, '🍕', 'PIZZAS', 'Media o entera', ARRAY['Media','Entera'])
  RETURNING id INTO sec_pizzas;

  INSERT INTO menu_items (seccion_id, item_orden, nombre, descripcion, precios) VALUES
    (sec_pizzas, 0, 'Común',       'Salsa, muzzarella, aceitunas',                                                    ARRAY['$7.000','$13.000']),
    (sec_pizzas, 1, 'Especial',    'Salsa, jamón, muzzarella, morrón, huevo duro, aceitunas',                         ARRAY['$8.000','$16.000']),
    (sec_pizzas, 2, 'Roquefort',   'Salsa, muzzarella, roquefort',                                                    ARRAY['$10.500','$20.000']),
    (sec_pizzas, 3, 'Napolitana',  'Salsa, muzzarella, orégano, ajo, tomate',                                         ARRAY['$10.500','$20.000']),
    (sec_pizzas, 4, 'Cantimpalo',  'Salsa, muzzarella, cantimpalo',                                                   ARRAY['$10.500','$20.000']),
    (sec_pizzas, 5, 'Fugazza',     'Salsa, cebolla, muzzarella',                                                      ARRAY['$8.000','$16.000']),
    (sec_pizzas, 6, 'Anchoas',     'Salsa, muzzarella, anchoas',                                                      ARRAY['$10.500','$20.000']),
    (sec_pizzas, 7, 'Pollo',       'Salsa, pollo con salsa blanca, muzzarella',                                       ARRAY['$13.000','$26.000']),
    (sec_pizzas, 8, 'Lescano',     'Salsa, pollo con salsa blanca, jamón, muzzarella, huevo frito, panceta, cheddar',ARRAY['$15.000','$28.000']);

  INSERT INTO menu_secciones (pagina, pagina_titulo, seccion_orden, emoji, titulo, nota, columnas)
  VALUES (3, 'Pizzas & Pizzanesas', 1, '🍕', 'PIZZANESAS', 'Con papas fritas', ARRAY['1 pers','2 pers','3 pers'])
  RETURNING id INTO sec_pizzanesas;

  INSERT INTO menu_items (seccion_id, item_orden, nombre, descripcion, precios) VALUES
    (sec_pizzanesas, 0, 'Común',      'Salsa, muzzarella, aceitunas',                           ARRAY['$13.000','$26.000','$39.000']),
    (sec_pizzanesas, 1, 'Napolitana', 'Salsa, jamón, muzzarella, tomate, orégano, ajo',         ARRAY['$15.000','$30.000','$45.000']),
    (sec_pizzanesas, 2, 'Roquefort',  'Salsa, muzzarella, roquefort',                           ARRAY['$15.000','$30.000','$45.000']),
    (sec_pizzanesas, 3, 'Lescano',    'Salsa, jamón, muzzarella, huevo frito, panceta, cheddar',ARRAY['$17.000','$34.000','$48.000']);

  -- ── PÁGINA 4: Torpedos & Carlitos ─────────────────────────────────────────
  INSERT INTO menu_secciones (pagina, pagina_titulo, seccion_orden, emoji, titulo, nota)
  VALUES (4, 'Torpedos & Carlitos', 0, '🥖', 'TORPEDOS', 'Solo o con papas')
  RETURNING id INTO sec_torpedos;

  INSERT INTO menu_items (seccion_id, item_orden, nombre, descripcion, precios) VALUES
    (sec_torpedos, 0, 'Común',       'Mayonesa, jamón, queso, lechuga, tomate',                                               ARRAY['$15.000']),
    (sec_torpedos, 1, 'Hamburguesa', 'Mayonesa, tres medallones 120g, jamón, queso, lechuga, tomate',                         ARRAY['$23.000']),
    (sec_torpedos, 2, 'Lescano',     'Mayonesa, suprema/milanesa, jamón, queso, huevo, cheddar, panceta, lechuga, tomate',   ARRAY['$29.000']);

  INSERT INTO menu_secciones (pagina, pagina_titulo, seccion_orden, emoji, titulo, nota)
  VALUES (4, 'Torpedos & Carlitos', 1, '🥪', 'CARLITOS / TOSTADOS', '')
  RETURNING id INTO sec_carlitos;

  INSERT INTO menu_items (seccion_id, item_orden, nombre, descripcion, precios) VALUES
    (sec_carlitos, 0, 'Común (simple)',        'Aderezo, jamón, queso',                            ARRAY['$9.000']),
    (sec_carlitos, 1, 'Especial (triple)',      'Aderezo, jamón, queso, huevo, aceitunas, morrón', ARRAY['$14.000']),
    (sec_carlitos, 2, 'Carne mechada (triple)','Aderezo, jamón, queso, carne mechada',             ARRAY['$20.000']),
    (sec_carlitos, 3, 'Lescano (triple)',       'Aderezo, cheddar, jamón, queso, huevo frito, pollo, panceta', ARRAY['$19.000']),
    (sec_carlitos, 4, 'Pollo (triple)',         'Aderezo, jamón, queso, pollo',                    ARRAY['$16.000']);

  -- ── PÁGINA 5: Guarniciones & Bebidas ──────────────────────────────────────
  INSERT INTO menu_secciones (pagina, pagina_titulo, seccion_orden, emoji, titulo, nota)
  VALUES (5, 'Guarniciones & Bebidas', 0, '🍟', 'GUARNICIONES', '')
  RETURNING id INTO sec_guarni;

  INSERT INTO menu_items (seccion_id, item_orden, nombre, descripcion, precios) VALUES
    (sec_guarni, 0, 'Bandeja de papas fritas',                '',                         ARRAY['$7.000']),
    (sec_guarni, 1, 'Bandeja de papas fritas cheddar y panceta', '',                      ARRAY['$10.000']),
    (sec_guarni, 2, 'Cono de papas',                          '',                         ARRAY['$5.000']),
    (sec_guarni, 3, 'Tortilla clásica',                       '',                         ARRAY['$10.000']),
    (sec_guarni, 4, 'Tortilla rellena',                       'Rellena de jamón y queso', ARRAY['$13.000']),
    (sec_guarni, 5, 'Tortilla lescano',                       'Rellena de milanesa, cheddar y panceta', ARRAY['$17.000']);

  INSERT INTO menu_secciones (pagina, pagina_titulo, seccion_orden, emoji, titulo, nota)
  VALUES (5, 'Guarniciones & Bebidas', 1, '🥤', 'BEBIDAS SIN ALCOHOL', '')
  RETURNING id INTO sec_bebidas;

  INSERT INTO menu_items (seccion_id, item_orden, nombre, descripcion, precios) VALUES
    (sec_bebidas, 0, 'Gaseosa 500ml',         '', ARRAY['$3.500']),
    (sec_bebidas, 1, 'Agua 500ml',            '', ARRAY['$3.000']),
    (sec_bebidas, 2, 'Agua saborizada 500ml', '', ARRAY['$3.000']),
    (sec_bebidas, 3, 'Gaseosa 1,25L',         '', ARRAY['$7.000']);

  INSERT INTO menu_secciones (pagina, pagina_titulo, seccion_orden, emoji, titulo, nota)
  VALUES (5, 'Guarniciones & Bebidas', 2, '🍺', 'CERVEZAS', '')
  RETURNING id INTO sec_cervezas;

  INSERT INTO menu_items (seccion_id, item_orden, nombre, descripcion, precios) VALUES
    (sec_cervezas, 0, 'Lata Isenbeck 473cc', '', ARRAY['$4.000']),
    (sec_cervezas, 1, 'Lata Schneider 710cc','', ARRAY['$7.000']),
    (sec_cervezas, 2, 'Quilmes 1lt',         '', ARRAY['$8.000']),
    (sec_cervezas, 3, 'Stella 1lt',          '', ARRAY['$10.000']);

  INSERT INTO menu_secciones (pagina, pagina_titulo, seccion_orden, emoji, titulo, nota)
  VALUES (5, 'Guarniciones & Bebidas', 3, '🍹', 'TRAGOS', '')
  RETURNING id INTO sec_tragos;

  INSERT INTO menu_items (seccion_id, item_orden, nombre, descripcion, precios) VALUES
    (sec_tragos, 0, 'Fernet',                   '', ARRAY['$0']),
    (sec_tragos, 1, 'Gancia con Sprite y limón', '', ARRAY['$0']),
    (sec_tragos, 2, 'Gin tonic de frutos rojos', '', ARRAY['$0']),
    (sec_tragos, 3, 'Destornillador',            '', ARRAY['$0']),
    (sec_tragos, 4, 'Amargo obrero',             '', ARRAY['$0']);

  -- ── PÁGINA 6: Promos ──────────────────────────────────────────────────────
  INSERT INTO menu_secciones (pagina, pagina_titulo, pagina_tipo, pagina_subtitulo, seccion_orden, titulo)
  VALUES (6, 'Promos', 'promos', 'Viernes, Sábado y Domingo (solo en efectivo)', 0, '')
  RETURNING id INTO sec_promos;

  INSERT INTO menu_items (seccion_id, item_orden, nombre, descripcion, precios) VALUES
    (sec_promos, 0, 'Pizza Especial + Pizza de Muzza',                '',  ARRAY['$25.000']),
    (sec_promos, 1, 'Dos Pizzas de Muzza',                           '',  ARRAY['$22.000']),
    (sec_promos, 2, 'Pizza de Muzza + Carlito Común + Cono de Papas','',  ARRAY['$24.000']),
    (sec_promos, 3, 'Carlitos especial + bandeja de papas',          '',  ARRAY['$17.000']),
    (sec_promos, 4, 'Carlito común + pizza de muzza',                '',  ARRAY['$19.000']);

END $$;
