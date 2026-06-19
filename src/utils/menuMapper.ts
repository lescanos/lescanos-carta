import type { MenuPagina, MenuSeccionRow, MenuItemRow } from '@/types/domain'

/**
 * Convierte filas de menu_secciones + menu_items a la estructura MenuPagina[]
 * que usa CartaPage. Función pura — sin side effects, fácil de testear.
 */
export function dbRowsToMenuPaginas(
  secciones: MenuSeccionRow[],
  items: MenuItemRow[],
): MenuPagina[] {
  if (secciones.length === 0) return []

  // Agrupar items por seccion_id
  const itemsBySec = new Map<string, MenuItemRow[]>()
  for (const item of items) {
    if (!itemsBySec.has(item.seccion_id)) itemsBySec.set(item.seccion_id, [])
    itemsBySec.get(item.seccion_id)!.push(item)
  }

  // Agrupar secciones por número de página
  const paginaMap = new Map<number, MenuSeccionRow[]>()
  for (const sec of secciones) {
    if (!paginaMap.has(sec.pagina)) paginaMap.set(sec.pagina, [])
    paginaMap.get(sec.pagina)!.push(sec)
  }

  const paginas: MenuPagina[] = []

  for (const [pagina, secRows] of [...paginaMap.entries()].sort(([a], [b]) => a - b)) {
    const first = secRows[0]

    if (first.pagina_tipo === 'promos') {
      // Página de promos: los items van directo en la página, sin secciones
      const promoItems = secRows
        .sort((a, b) => a.seccion_orden - b.seccion_orden)
        .flatMap(s =>
          (itemsBySec.get(s.id) ?? [])
            .sort((a, b) => a.item_orden - b.item_orden)
            .map(item => ({ nombre: item.nombre, precio: item.precios[0] ?? '$0' })),
        )
      paginas.push({
        pagina: String(pagina),
        titulo: first.pagina_titulo,
        tipo: 'promos',
        subtitulo: first.pagina_subtitulo ?? undefined,
        secciones: [],
        items: promoItems,
      })
    } else {
      // Página regular: items dentro de secciones
      const mapped = secRows
        .sort((a, b) => a.seccion_orden - b.seccion_orden)
        .map(sec => {
          const secItems = (itemsBySec.get(sec.id) ?? [])
            .sort((a, b) => a.item_orden - b.item_orden)
            .map(item => {
              const base = {
                nombre: item.nombre,
                desc: item.descripcion ?? undefined,
              }
              // Multi-precio (columnas) vs precio único
              return item.precios.length > 1
                ? { ...base, precios: item.precios }
                : { ...base, precio: item.precios[0] ?? '$0' }
            })
          return {
            emoji: sec.emoji ?? undefined,
            titulo: sec.titulo,
            nota: sec.nota ?? undefined,
            columnas: sec.columnas ?? undefined,
            va_a_cocina: sec.va_a_cocina,
            items: secItems,
          }
        })
      paginas.push({
        pagina: String(pagina),
        titulo: first.pagina_titulo,
        secciones: mapped,
      })
    }
  }

  return paginas
}
