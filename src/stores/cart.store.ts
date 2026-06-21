import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from '@/services/supabase'
import { useAuthStore } from '@/stores/auth.store'
import { timeBsAs } from '@/utils/timezone'
import type { CartItem, PedidoItem, Sesion, EstadoPedido } from '@/types/domain'
import type { SessionPedidoRef } from '@/utils/sessionGroups'

export const useCartStore = defineStore('cart', () => {
  const auth = useAuthStore()

  // ── State ────────────────────────────────────────────
  const mesaKey        = ref<string | null>(null)  // 'mesa_1', 'llevar', 'envio_...'
  const cart           = ref<CartItem[]>([])
  const currentSession = ref<Sesion | null>(null)
  const sessionItems   = ref<PedidoItem[]>([])
  const sessionPedidos = ref<SessionPedidoRef[]>([])
  const cubiertos      = ref(1)

  // ── Computed ─────────────────────────────────────────
  const cartCount   = computed(() => cart.value.reduce((s, c) => s + c.qty, 0))
  const cartTotal   = computed(() => cart.value.reduce((s, c) => s + parsePrecio(c.precio) * c.qty, 0))
  const sessionTotal = computed(() => sessionItems.value.reduce((s, c) => s + parsePrecio(c.precio) * c.qty, 0))
  const grandTotal  = computed(() => cartTotal.value + sessionTotal.value)
  const hasRealPrices = computed(() =>
    cart.value.some(c => parsePrecio(c.precio) > 0) ||
    sessionItems.value.some(c => parsePrecio(c.precio) > 0)
  )
  const mesaLabel = computed(() => {
    if (!mesaKey.value) return ''
    if (mesaKey.value === 'llevar' || mesaKey.value.startsWith('llevar_'))
      return currentSession.value?.cliente_nombre
        ? `Llevar — ${currentSession.value.cliente_nombre}`
        : 'Para llevar'
    if (mesaKey.value.startsWith('envio_'))
      return currentSession.value?.cliente_nombre
        ? `Envío — ${currentSession.value.cliente_nombre}`
        : 'Envío'
    return `Mesa ${mesaKey.value.replace('mesa_', '')}`
  })

  // ── Helpers ──────────────────────────────────────────
  function parsePrecio(p: string | undefined): number {
    return parseInt((p || '').replace(/\D/g, '')) || 0
  }

  function lsKey(): string {
    return `lescanos_order_${mesaKey.value ?? 'unknown'}`
  }

  function cartLoad() {
    try { cart.value = JSON.parse(localStorage.getItem(lsKey()) || '[]') }
    catch { cart.value = [] }
  }

  function cartSave() {
    cart.value.length
      ? localStorage.setItem(lsKey(), JSON.stringify(cart.value))
      : localStorage.removeItem(lsKey())
  }

  function cartClear() {
    localStorage.removeItem(lsKey())
    cart.value = []
  }

  // ── Cart ops ─────────────────────────────────────────
  function addItem(item: CartItem) {
    const existing = cart.value.find(c => c.id === item.id)
    if (existing) existing.qty++
    else cart.value.push({ ...item, qty: 1 })
    cartSave()
  }

  function removeItem(id: string) {
    const i = cart.value.findIndex(c => c.id === id)
    if (i === -1) return
    if (cart.value[i].qty > 1) cart.value[i].qty--
    else cart.value.splice(i, 1)
    cartSave()
  }

  function removeCartEntry(idx: number) {
    const item = cart.value[idx]
    if (!item) return
    if (item.qty > 1) item.qty--
    else cart.value.splice(idx, 1)
    cartSave()
  }

  function setItemNote(idx: number, nota: string | null) {
    if (cart.value[idx]) {
      cart.value[idx].nota = nota || undefined
      cartSave()
    }
  }

  // ── Supabase session ops ──────────────────────────────
  async function openOrLoadSession(key: string) {
    const { data } = await supabase
      .from('sesiones')
      .select('*')
      .eq('mesa', key)
      .eq('estado', 'abierta')
      .order('created_at', { ascending: false })
      .limit(1)

    if (data && data.length > 0) {
      currentSession.value = data[0] as Sesion
      cubiertos.value = data[0].cubiertos || 1
      await loadSessionItems()
    } else {
      const tipo = key.startsWith('envio_') ? 'envio' : key.startsWith('llevar') ? 'llevar' : 'mesa'
      const { data: created, error } = await supabase
        .from('sesiones')
        .insert({
          mesa: key,
          estado: 'abierta',
          tipo,
          moza_id: auth.currentUser?.id ?? null,
          moza_nombre: auth.currentUser?.nombre ?? null,
        })
        .select()
        .single()
      if (error) throw error
      currentSession.value = created as Sesion
      cubiertos.value = 1
      sessionItems.value = []
    }
  }

  async function loadSessionItems() {
    if (!currentSession.value) return
    const [{ data: items }, { data: pedidos }] = await Promise.all([
      supabase
        .from('pedido_items')
        .select('*')
        .eq('sesion_id', currentSession.value.id)
        .order('created_at', { ascending: true }),
      supabase
        .from('pedidos')
        .select('id, estado, tipo, created_at')
        .eq('sesion_id', currentSession.value.id)
        .order('created_at', { ascending: true }),
    ])
    sessionItems.value = (items as PedidoItem[]) ?? []
    sessionPedidos.value = (pedidos as SessionPedidoRef[]) ?? []
  }

  function updatePedidoEstado(id: string, estado: EstadoPedido) {
    const p = sessionPedidos.value.find(p => p.id === id)
    if (p) p.estado = estado
  }

  async function setCubiertos(n: number) {
    cubiertos.value = Math.max(1, n)
    if (currentSession.value) {
      await supabase
        .from('sesiones')
        .update({ cubiertos: cubiertos.value })
        .eq('id', currentSession.value.id)
    }
  }

  async function saveOrder(): Promise<boolean> {
    if (!currentSession.value || cart.value.length === 0) return false

    const cocinaItems = cart.value.filter(c => c.va_a_cocina !== false)
    const barraItems  = cart.value.filter(c => c.va_a_cocina === false)

    async function insertPedido(tipo: 'pedido' | 'barra', items: typeof cart.value) {
      if (items.length === 0) return
      const { data: pedido, error: pErr } = await supabase
        .from('pedidos')
        .insert({ sesion_id: currentSession.value!.id, tipo })
        .select()
        .single()
      if (pErr) throw pErr
      const rows = items.map(c => ({
        pedido_id: pedido.id,
        sesion_id: currentSession.value!.id,
        nombre: c.nombre,
        precio: c.precio,
        qty: c.qty,
        nota: c.nota ?? null,
        pagina: c.pagina ?? '',
        seccion: c.seccion ?? '',
      }))
      const { error: iErr } = await supabase.from('pedido_items').insert(rows)
      if (iErr) throw iErr
    }

    await insertPedido('pedido', cocinaItems)
    await insertPedido('barra', barraItems)
    await loadSessionItems()
    return true
  }

  async function sendCambio(originalItem: PedidoItem, descripcion: string) {
    if (!currentSession.value || !descripcion.trim()) return
    const { data: pedido, error: pErr } = await supabase
      .from('pedidos')
      .insert({ sesion_id: currentSession.value.id, tipo: 'cambio' })
      .select()
      .single()
    if (pErr) throw pErr
    await supabase.from('pedido_items').insert({
      pedido_id: pedido.id,
      sesion_id: currentSession.value.id,
      nombre: descripcion.trim(),
      nota: 'Cambio de: ' + originalItem.nombre,
      qty: 1,
      precio: '$0',
      seccion: 'CAMBIO',
    })
  }

  async function sendCancelacion(item: PedidoItem) {
    if (!currentSession.value) return
    const { data: pedido, error: pErr } = await supabase
      .from('pedidos')
      .insert({ sesion_id: currentSession.value.id, tipo: 'cancelacion' })
      .select()
      .single()
    if (pErr) throw pErr
    await supabase.from('pedido_items').insert({
      pedido_id: pedido.id,
      sesion_id: currentSession.value.id,
      nombre: item.nombre,
      nota: item.nota ?? null,
      qty: item.qty,
      precio: '$0',
      seccion: 'CANCELACION',
    })
  }

  async function addPago(metodo: string, monto: number) {
    if (!currentSession.value || !metodo) return
    await supabase.from('pagos').insert({
      sesion_id: currentSession.value.id,
      metodo,
      monto,
    })
  }

  async function closeSessionOnly() {
    if (!currentSession.value) { clearState(); return }
    await supabase
      .from('sesiones')
      .update({ estado: 'cerrada', closed_at: new Date().toISOString(), cubiertos: cubiertos.value })
      .eq('id', currentSession.value.id)
    clearState()
  }

  async function closeSession(metodo: string, monto: number) {
    if (!currentSession.value) {
      clearState()
      return
    }
    await supabase
      .from('sesiones')
      .update({ estado: 'cerrada', closed_at: new Date().toISOString(), cubiertos: cubiertos.value })
      .eq('id', currentSession.value.id)
    if (metodo) {
      await supabase.from('pagos').insert({
        sesion_id: currentSession.value.id,
        metodo,
        monto,
      })
    }
    clearState()
  }

  async function deleteSessionIfEmpty() {
    if (currentSession.value && cart.value.length === 0 && sessionItems.value.length === 0) {
      await supabase.from('sesiones').delete().eq('id', currentSession.value.id)
    }
  }

  function clearState() {
    mesaKey.value = null
    cart.value = []
    currentSession.value = null
    sessionItems.value = []
    sessionPedidos.value = []
    cubiertos.value = 1
  }

  // ── WhatsApp msg builder ──────────────────────────────
  function buildMsg(): string {
    const { hh, mm } = timeBsAs()
    let msg = `*${mesaLabel.value} — ${hh}:${mm}*\n`
    const byPage: Record<string, Record<string, CartItem[]>> = {}
    const pageOrder: string[] = []
    cart.value.forEach(item => {
      const pg = item.pagina ?? ''
      const sec = item.seccion ?? ''
      if (!byPage[pg]) { byPage[pg] = {}; pageOrder.push(pg) }
      if (!byPage[pg][sec]) byPage[pg][sec] = []
      byPage[pg][sec].push(item)
    })
    pageOrder.forEach(pg => {
      const secs = byPage[pg]
      const secKeys = Object.keys(secs)
      if (pg) msg += `\n*${pg}*\n`
      secKeys.forEach(sec => {
        if (sec && secKeys.length > 1) msg += `_${sec}_\n`
        secs[sec].forEach(item => {
          const p = (item.precio && item.precio !== '$0') ? ` — ${item.precio}` : ''
          const n = item.nota ? ` _(${item.nota})_` : ''
          msg += `• ${item.qty}× ${item.nombre}${p}${n}\n`
        })
      })
    })
    if (cart.value.some(c => parsePrecio(c.precio) > 0)) {
      msg += `\n*Subtotal: $${cartTotal.value.toLocaleString('es-AR')}*`
    }
    return msg.trim()
  }

  return {
    mesaKey, cart, currentSession, sessionItems, sessionPedidos, cubiertos,
    cartCount, cartTotal, sessionTotal, grandTotal, hasRealPrices, mesaLabel,
    parsePrecio, cartLoad, cartClear,
    addItem, removeItem, removeCartEntry, setItemNote,
    openOrLoadSession, loadSessionItems, setCubiertos,
    saveOrder, sendCambio, sendCancelacion, addPago, closeSessionOnly, closeSession, deleteSessionIfEmpty, clearState,
    updatePedidoEstado,
    buildMsg,
  }
})
