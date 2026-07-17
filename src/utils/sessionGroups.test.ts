import { describe, it, expect } from 'vitest'
import { buildSessionGroups } from './sessionGroups'
import type { SessionPedidoRef } from './sessionGroups'
import type { PedidoItem } from '@/types/domain'

const basePedido = (overrides: Partial<SessionPedidoRef> = {}): SessionPedidoRef => ({
  id: 'p1',
  estado: 'pendiente',
  tipo: 'pedido',
  created_at: '2024-01-14T20:00:00Z',
  ...overrides,
})

const baseItem = (overrides: Partial<PedidoItem> = {}): PedidoItem => ({
  id: 'item-1',
  pedido_id: 'p1',
  sesion_id: 'ses-1',
  nombre: 'Elmer Fudd',
  precio: '$14.000',
  qty: 1,
  nota: null,
  seccion: 'HAMBURGUESAS',
  created_at: '2024-01-14T20:00:01Z',
  entregado_qty: 0,
  cancelado: false,
  ...overrides,
})

describe('buildSessionGroups', () => {
  it('devuelve array vacío si no hay items', () => {
    expect(buildSessionGroups([], [basePedido()])).toEqual([])
  })

  it('devuelve array vacío si no hay pedidos', () => {
    expect(buildSessionGroups([baseItem()], [])).toEqual([])
  })

  it('agrupa items bajo su pedido', () => {
    const item1 = baseItem({ id: 'i1', nombre: 'Elmer' })
    const item2 = baseItem({ id: 'i2', nombre: 'Taz' })
    const result = buildSessionGroups([item1, item2], [basePedido()])
    expect(result).toHaveLength(1)
    expect(result[0].items).toHaveLength(2)
  })

  it('crea grupos separados para pedidos distintos', () => {
    const p1 = basePedido({ id: 'p1', created_at: '2024-01-14T20:00:00Z' })
    const p2 = basePedido({ id: 'p2', tipo: 'barra', created_at: '2024-01-14T20:05:00Z' })
    const item1 = baseItem({ id: 'i1', pedido_id: 'p1' })
    const item2 = baseItem({ id: 'i2', pedido_id: 'p2' })
    const result = buildSessionGroups([item1, item2], [p1, p2])
    expect(result).toHaveLength(2)
    expect(result[0].pedido.id).toBe('p1')
    expect(result[1].pedido.id).toBe('p2')
  })

  it('ordena grupos por created_at del pedido', () => {
    const p1 = basePedido({ id: 'p1', created_at: '2024-01-14T20:10:00Z' })
    const p2 = basePedido({ id: 'p2', created_at: '2024-01-14T19:55:00Z' })
    const item1 = baseItem({ id: 'i1', pedido_id: 'p1' })
    const item2 = baseItem({ id: 'i2', pedido_id: 'p2' })
    const result = buildSessionGroups([item1, item2], [p1, p2])
    expect(result[0].pedido.id).toBe('p2')
    expect(result[1].pedido.id).toBe('p1')
  })

  it('ignora items con pedido_id desconocido', () => {
    const item = baseItem({ pedido_id: 'inexistente' })
    const result = buildSessionGroups([item], [basePedido({ id: 'otro' })])
    expect(result).toHaveLength(0)
  })

  it('preserva el estado del pedido en el grupo', () => {
    const result = buildSessionGroups([baseItem()], [basePedido({ estado: 'listo' })])
    expect(result[0].pedido.estado).toBe('listo')
  })

  it('preserva el tipo barra en el grupo', () => {
    const result = buildSessionGroups(
      [baseItem()],
      [basePedido({ tipo: 'barra' })],
    )
    expect(result[0].pedido.tipo).toBe('barra')
  })

  it('mantiene el orden de items dentro del grupo', () => {
    const item1 = baseItem({ id: 'i1', nombre: 'Primero' })
    const item2 = baseItem({ id: 'i2', nombre: 'Segundo' })
    const result = buildSessionGroups([item1, item2], [basePedido()])
    expect(result[0].items[0].nombre).toBe('Primero')
    expect(result[0].items[1].nombre).toBe('Segundo')
  })
})
