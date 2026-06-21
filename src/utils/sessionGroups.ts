import type { PedidoItem, EstadoPedido, TipoPedido } from '@/types/domain'

export interface SessionPedidoRef {
  id: string
  estado: EstadoPedido
  tipo: TipoPedido
  created_at: string
}

export interface SessionGroup {
  pedido: SessionPedidoRef
  items: PedidoItem[]
}

/**
 * Agrupa pedido_items por pedido, en orden cronológico.
 * Items sin pedido conocido se ignoran silenciosamente.
 */
export function buildSessionGroups(
  items: PedidoItem[],
  pedidos: SessionPedidoRef[],
): SessionGroup[] {
  const pedidoMap = new Map(pedidos.map(p => [p.id, p]))
  const groupMap = new Map<string, SessionGroup>()

  for (const item of items) {
    const pedido = pedidoMap.get(item.pedido_id)
    if (!pedido) continue
    if (!groupMap.has(item.pedido_id)) {
      groupMap.set(item.pedido_id, { pedido, items: [] })
    }
    groupMap.get(item.pedido_id)!.items.push(item)
  }

  return [...groupMap.values()].sort(
    (a, b) => new Date(a.pedido.created_at).getTime() - new Date(b.pedido.created_at).getTime(),
  )
}
