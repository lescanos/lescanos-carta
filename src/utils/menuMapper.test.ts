import { describe, it, expect } from 'vitest'
import { dbRowsToMenuPaginas } from './menuMapper'
import type { MenuSeccionRow, MenuItemRow } from '@/types/domain'

const baseSec = (overrides: Partial<MenuSeccionRow> = {}): MenuSeccionRow => ({
  id: 'sec-1',
  pagina: 1,
  pagina_titulo: 'Hamburguesas',
  pagina_tipo: 'regular',
  pagina_subtitulo: null,
  seccion_orden: 0,
  emoji: '🍔',
  titulo: 'HAMBURGUESAS',
  nota: 'Con papas',
  columnas: ['Solo', 'Con papas'],
  ...overrides,
})

const baseItem = (overrides: Partial<MenuItemRow> = {}): MenuItemRow => ({
  id: 'item-1',
  seccion_id: 'sec-1',
  item_orden: 0,
  nombre: 'Elmer Fudd',
  descripcion: 'Mayonesa, queso',
  precios: ['$8.000', '$14.000'],
  ...overrides,
})

describe('dbRowsToMenuPaginas', () => {
  it('devuelve array vacío si no hay secciones', () => {
    expect(dbRowsToMenuPaginas([], [])).toEqual([])
  })

  it('mapea página regular con item multi-precio', () => {
    const result = dbRowsToMenuPaginas([baseSec()], [baseItem()])
    expect(result).toHaveLength(1)
    expect(result[0].pagina).toBe('1')
    expect(result[0].titulo).toBe('Hamburguesas')
    expect(result[0].secciones).toHaveLength(1)
    const item = result[0].secciones![0].items[0]
    expect(item.precios).toEqual(['$8.000', '$14.000'])
    expect(item).not.toHaveProperty('precio')
  })

  it('mapea item de precio único a campo precio (no precios)', () => {
    const result = dbRowsToMenuPaginas(
      [baseSec({ columnas: null })],
      [baseItem({ precios: ['$15.000'] })],
    )
    const item = result[0].secciones![0].items[0]
    expect(item.precio).toBe('$15.000')
    expect(item.precios).toBeUndefined()
  })

  it('propaga emoji, nota y columnas de la sección', () => {
    const result = dbRowsToMenuPaginas([baseSec()], [])
    const sec = result[0].secciones![0]
    expect(sec.emoji).toBe('🍔')
    expect(sec.nota).toBe('Con papas')
    expect(sec.columnas).toEqual(['Solo', 'Con papas'])
  })

  it('mapea página de promos correctamente', () => {
    const promoSec = baseSec({
      id: 'sec-p',
      pagina: 6,
      pagina_titulo: 'Promos',
      pagina_tipo: 'promos',
      pagina_subtitulo: 'Fines de semana',
      titulo: '',
      emoji: null,
      columnas: null,
      nota: null,
    })
    const promoItem = baseItem({
      seccion_id: 'sec-p',
      precios: ['$25.000'],
    })
    const result = dbRowsToMenuPaginas([promoSec], [promoItem])
    expect(result[0].tipo).toBe('promos')
    expect(result[0].subtitulo).toBe('Fines de semana')
    expect(result[0].secciones).toHaveLength(0)
    expect(result[0].items).toHaveLength(1)
    expect(result[0].items![0].precio).toBe('$25.000')
  })

  it('ordena páginas por número de página', () => {
    const sec2 = baseSec({ id: 'sec-2', pagina: 2, pagina_titulo: 'Panchos' })
    const result = dbRowsToMenuPaginas([sec2, baseSec()], [baseItem()])
    expect(result[0].pagina).toBe('1')
    expect(result[1].pagina).toBe('2')
  })

  it('ordena secciones dentro de una página por seccion_orden', () => {
    const sec0 = baseSec({ id: 's0', seccion_orden: 0, titulo: 'PRIMERO' })
    const sec1 = baseSec({ id: 's1', seccion_orden: 1, titulo: 'SEGUNDO' })
    const result = dbRowsToMenuPaginas([sec1, sec0], [])
    expect(result[0].secciones![0].titulo).toBe('PRIMERO')
    expect(result[0].secciones![1].titulo).toBe('SEGUNDO')
  })

  it('ordena items dentro de sección por item_orden', () => {
    const item0 = baseItem({ id: 'i0', item_orden: 0, nombre: 'Primero' })
    const item1 = baseItem({ id: 'i1', item_orden: 1, nombre: 'Segundo' })
    const result = dbRowsToMenuPaginas([baseSec()], [item1, item0])
    expect(result[0].secciones![0].items[0].nombre).toBe('Primero')
    expect(result[0].secciones![0].items[1].nombre).toBe('Segundo')
  })

  it('maneja sección sin items', () => {
    const result = dbRowsToMenuPaginas([baseSec()], [])
    expect(result[0].secciones![0].items).toHaveLength(0)
  })

  it('no propaga desc si es null', () => {
    const result = dbRowsToMenuPaginas([baseSec()], [baseItem({ descripcion: null })])
    expect(result[0].secciones![0].items[0].desc).toBeUndefined()
  })
})
