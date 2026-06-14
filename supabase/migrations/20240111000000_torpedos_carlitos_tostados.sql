-- ═══════════════════════════════════════════════════════════════════
--  Fix menú:
--  1. Torpedos → 2 columnas (Solo / Con papas)
--  2. Carlitos/Tostados → split en 2 secciones para que cocina distinga
-- ═══════════════════════════════════════════════════════════════════

-- ── 1. TORPEDOS: agregar columnas Solo / Con papas ───────────────────
UPDATE menu_secciones
SET columnas = ARRAY['Solo', 'Con papas']
WHERE pagina = 4 AND titulo = 'TORPEDOS';

-- Agrega un segundo precio igual al primero como placeholder.
-- El dueño debe actualizar los precios "Con papas" desde Admin → Menú.
UPDATE menu_items
SET precios = ARRAY[precios[1], precios[1]]
WHERE seccion_id = (
  SELECT id FROM menu_secciones WHERE pagina = 4 AND titulo = 'TORPEDOS'
);

-- ── 2. CARLITOS / TOSTADOS: dividir en 2 secciones ──────────────────

-- Renombrar sección existente a TOSTADOS
UPDATE menu_secciones
SET titulo = 'TOSTADOS'
WHERE pagina = 4 AND titulo = 'CARLITOS / TOSTADOS';

-- Crear sección CARLITOS con los mismos ítems y precios
DO $$
DECLARE
  sec_tostados uuid;
  sec_carlitos  uuid;
BEGIN
  SELECT id INTO sec_tostados
  FROM menu_secciones
  WHERE pagina = 4 AND titulo = 'TOSTADOS';

  INSERT INTO menu_secciones (pagina, pagina_titulo, seccion_orden, emoji, titulo, nota)
  VALUES (4, 'Torpedos & Carlitos', 2, '🥪', 'CARLITOS', '')
  RETURNING id INTO sec_carlitos;

  INSERT INTO menu_items (seccion_id, item_orden, nombre, descripcion, precios)
  SELECT sec_carlitos, item_orden, nombre, descripcion, precios
  FROM menu_items
  WHERE seccion_id = sec_tostados
  ORDER BY item_orden;
END $$;
