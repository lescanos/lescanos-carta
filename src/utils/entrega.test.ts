import { describe, it, expect } from 'vitest'
import { nextEntregadoQty, entregadoStatus } from './entrega'

describe('nextEntregadoQty', () => {
  it('incrementa desde 0', () => {
    expect(nextEntregadoQty(0, 2)).toBe(1)
  })

  it('incrementa desde parcial', () => {
    expect(nextEntregadoQty(1, 2)).toBe(2)
  })

  it('resetea a 0 cuando llega al máximo', () => {
    expect(nextEntregadoQty(2, 2)).toBe(0)
  })

  it('no supera el máximo', () => {
    expect(nextEntregadoQty(3, 2)).toBe(0)
  })

  it('funciona con qty = 1', () => {
    expect(nextEntregadoQty(0, 1)).toBe(1)
    expect(nextEntregadoQty(1, 1)).toBe(0)
  })

  it('funciona con qty = 3', () => {
    expect(nextEntregadoQty(0, 3)).toBe(1)
    expect(nextEntregadoQty(1, 3)).toBe(2)
    expect(nextEntregadoQty(2, 3)).toBe(3)
    expect(nextEntregadoQty(3, 3)).toBe(0)
  })
})

describe('entregadoStatus', () => {
  it('ninguno entregado → none', () => {
    expect(entregadoStatus(0, 2)).toBe('none')
  })

  it('entrega parcial → partial', () => {
    expect(entregadoStatus(1, 2)).toBe('partial')
    expect(entregadoStatus(2, 3)).toBe('partial')
  })

  it('entrega completa → full', () => {
    expect(entregadoStatus(2, 2)).toBe('full')
    expect(entregadoStatus(3, 3)).toBe('full')
  })

  it('valor negativo → none', () => {
    expect(entregadoStatus(-1, 2)).toBe('none')
  })
})
