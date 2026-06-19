export function nextEntregadoQty(current: number, max: number): number {
  return current >= max ? 0 : current + 1
}

export function entregadoStatus(current: number, max: number): 'none' | 'partial' | 'full' {
  if (current <= 0) return 'none'
  if (current >= max) return 'full'
  return 'partial'
}
