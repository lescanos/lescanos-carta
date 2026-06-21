<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/services/supabase'
import { useAuthStore } from '@/stores/auth.store'
import { useCartStore } from '@/stores/cart.store'
import { timeBsAs } from '@/utils/timezone'
import type { Sesion, MenuPagina, PedidoItem } from '@/types/domain'
import { nextEntregadoQty, entregadoStatus } from '@/utils/entrega'
import { buildSessionGroups } from '@/utils/sessionGroups'

const router = useRouter()
const auth   = useAuthStore()
const cart   = useCartStore()

// ── View state ────────────────────────────────────────
type View = 'mesas' | 'menu' | 'resumen' | 'split'
const view = ref<View>('mesas')

// ── Mesa grid state ───────────────────────────────────
const numMesas         = ref(8)
const openSessions     = ref<Record<string, Sesion>>({})
const deliverySessions = ref<Sesion[]>([])
const llevarSessions   = ref<Sesion[]>([])

// ── Menu state ────────────────────────────────────────
type ItemMeta = {
  nombre: string; desc?: string; precio?: string; precios?: string[]
  pagina: string; seccion: string; _columnas?: string[]; va_a_cocina?: boolean
}
const menuPages = ref<MenuPagina[]>([])
const pageIdx   = ref(0)
const itemsMap  = ref<Record<string, ItemMeta>>({})

// ── UI state ──────────────────────────────────────────
const loading      = ref(false)
const toastMsg     = ref('')
let   toastTimer: ReturnType<typeof setTimeout> | null = null

// Modals
const confirmMesaKey = ref<string | null>(null)
const noteIdx        = ref<number | null>(null)
const noteText       = ref('')
const cambioItem     = ref<PedidoItem | null>(null)
const cambioText     = ref('')
const payVisible     = ref(false)
const selectedPay    = ref('')
const delFormVisible = ref(false)
const delNombre      = ref('')
const delTel         = ref('')
const delDir         = ref('')
const delRef         = ref('')
const delMetodo      = ref('')

const llevarFormVisible = ref(false)
const llevarNombre      = ref('')
const llevarTel         = ref('')

// Listo notification
const listoText    = ref('')
const listoVisible = ref(false)
let   listoTimer: ReturnType<typeof setTimeout> | null = null

// Fallback WA text
const fallbackMsg  = ref('')
const showFallback = ref(false)
const sendingOrder = ref(false)

// Split billing
const splitCount        = ref(2)
const splitAssignment   = ref<Record<string, number>>({})
const splitPaid         = ref<boolean[]>([false, false])
const splitPayingPerson = ref(-1)

// Realtime
let realtimeChannel: ReturnType<typeof supabase.channel> | null = null
let listoChannel:    ReturnType<typeof supabase.channel> | null = null
let entregaChannel:  ReturnType<typeof supabase.channel> | null = null

const WA_NUMBER = import.meta.env.VITE_WA_NUMBER ?? ''

// ── Menu data ─────────────────────────────────────────
function getMenu(): MenuPagina[] {
  try {
    const s = localStorage.getItem('lescanos_carta')
    const fallback = (window as unknown as Record<string, unknown>)['DEFAULT_CARTA'] as MenuPagina[] | undefined
    return s ? JSON.parse(s) : (fallback ?? [])
  } catch { return [] }
}

// ── Config from Supabase ──────────────────────────────
const costoEnvio = ref(0)

async function loadConfig() {
  const { data } = await supabase.from('config').select('clave,valor').in('clave', ['num_mesas', 'costo_envio'])
  data?.forEach(row => {
    if (row.clave === 'num_mesas') numMesas.value = parseInt(row.valor) || 8
    if (row.clave === 'costo_envio') costoEnvio.value = parseInt(row.valor) || 0
  })
}

// ── Open sessions ─────────────────────────────────────
async function loadOpenSessions() {
  openSessions.value = {}
  deliverySessions.value = []
  llevarSessions.value = []
  const { data, error } = await supabase
    .from('sesiones')
    .select('mesa,id,created_at,tipo,moza_id,moza_nombre,cliente_nombre,cliente_telefono,cliente_direccion,cliente_referencia,metodo_pago,cubiertos,estado,closed_at')
    .eq('estado', 'abierta')
  if (error) return
  ;(data as Sesion[]).forEach(s => {
    if (s.tipo === 'envio') deliverySessions.value.push(s)
    else if (s.tipo === 'llevar') llevarSessions.value.push(s)
    else openSessions.value[s.mesa] = s
  })
}

// ── Mesa grid items ───────────────────────────────────
const mesaItems = computed(() => {
  type MesaItem = { key: string; num: string; active: boolean; moza: string | null }
  const items: MesaItem[] = []
  for (let i = 1; i <= numMesas.value; i++) {
    const key = `mesa_${i}`
    const sess = openSessions.value[key]
    items.push({ key, num: String(i), active: !!sess, moza: sess?.moza_nombre ?? null })
  }
  return items
})

function mesaKeyLabel(key: string): string {
  if (key === 'llevar' || key.startsWith('llevar_')) return 'Para llevar'
  if (key.startsWith('envio_')) return 'Envío'
  return `Mesa ${key.replace('mesa_', '')}`
}

// ── Enter mesa ────────────────────────────────────────
async function handleMesaClick(key: string) {
  const sess = openSessions.value[key]
  if (sess) {
    const isMine = sess.moza_id === auth.currentUser?.id
    const canAll = auth.can('caja', 'dueno')
    if (!isMine && !canAll) {
      showToast('Mesa de ' + (sess.moza_nombre || 'otra moza') + ' — no podés entrar')
      return
    }
    await enterMesa(key)
  } else {
    confirmMesaKey.value = key
  }
}

async function confirmOpenMesa() {
  const key = confirmMesaKey.value
  confirmMesaKey.value = null
  if (key) await enterMesa(key)
}

async function enterMesa(key: string) {
  loading.value = true
  cart.mesaKey = key
  cart.cartLoad()
  pageIdx.value = 0
  menuPages.value = getMenu()
  buildItemsMap()
  showFallback.value = false
  view.value = 'menu'
  try {
    await cart.openOrLoadSession(key)
    if (cart.currentSession?.id) setupEntregaRealtime(cart.currentSession.id)
  }
  catch { showToast('Sin conexión — modo local') }
  loading.value = false
}

async function backToMesas() {
  await cart.deleteSessionIfEmpty()
  cart.clearState()
  await loadOpenSessions()
  showFallback.value = false
  view.value = 'mesas'
}

// ── Menu rendering ────────────────────────────────────
function buildItemsMap() {
  itemsMap.value = {}
  menuPages.value.forEach((page, pi) => {
    if (page.tipo === 'promos') {
      ;(page.items || []).forEach((item, ii) => {
        const id = `promo-${pi}-${ii}`
        itemsMap.value[id] = { nombre: item.nombre, pagina: page.titulo, seccion: '', precio: item.precio ?? '$0' }
      })
    } else {
      ;(page.secciones || []).forEach((sec, si) => {
        sec.items.forEach((item, ii) => {
          const baseId = `p${pi}s${si}i${ii}`
          if (sec.columnas) {
            itemsMap.value[baseId] = { nombre: item.nombre, desc: item.desc, pagina: page.titulo, seccion: sec.titulo, _columnas: sec.columnas, precios: item.precios, va_a_cocina: sec.va_a_cocina }
          } else {
            itemsMap.value[baseId] = { nombre: item.nombre, desc: item.desc, pagina: page.titulo, seccion: sec.titulo, precio: item.precio ?? (item.precios?.[0] ?? '$0'), va_a_cocina: sec.va_a_cocina }
          }
        })
      })
    }
  })
}

const currentPage = computed<MenuPagina | null>(() => menuPages.value[pageIdx.value] ?? null)

// ── Cancelados ────────────────────────────────────────
// Nombres de ítems que tienen una entrada de CANCELACION en sessionItems
const cancelledNames = computed(() =>
  new Set(cart.sessionItems.filter(i => i.seccion === 'CANCELACION').map(i => i.nombre))
)

// sessionItems visibles: sin CANCELACION ni CAMBIO
const sessionItemsDisplay = computed(() =>
  cart.sessionItems.filter(i => i.seccion !== 'CANCELACION' && i.seccion !== 'CAMBIO')
)

const todoEntregado = computed(() =>
  sessionItemsDisplay.value.length > 0 &&
  sessionItemsDisplay.value
    .filter(i => !cancelledNames.value.has(i.nombre))
    .every(i => i.entregado_qty >= i.qty)
)

const sessionPedidoGroups = computed(() =>
  buildSessionGroups(sessionItemsDisplay.value, cart.sessionPedidos)
)

// Total ajustado: sin ítems cancelados ni CAMBIO/CANCELACION
const sessionTotalAdjusted = computed(() =>
  sessionItemsDisplay.value
    .filter(i => !cancelledNames.value.has(i.nombre))
    .reduce((s, i) => s + cart.parsePrecio(i.precio) * i.qty, 0)
)

const grandTotalAdjusted = computed(() => {
  const base = cart.cartTotal + sessionTotalAdjusted.value
  return cart.mesaKey?.startsWith('envio_') ? base + costoEnvio.value : base
})

const allSplitItems = computed(() => {
  const out: Array<{ splitKey: string; nombre: string; precio?: string; qty: number; nota?: string; isCart: boolean }> = []
  cart.cart.forEach((item, idx) => out.push({ nombre: item.nombre, precio: item.precio, qty: item.qty, nota: item.nota, splitKey: `c${idx}`, isCart: true }))
  cart.sessionItems.forEach((item, idx) => out.push({ nombre: item.nombre, precio: item.precio ?? undefined, qty: item.qty, nota: item.nota ?? undefined, splitKey: `s${idx}`, isCart: false }))
  return out
})

const splitTotals = computed(() =>
  Array.from({ length: splitCount.value }, (_, pi) =>
    allSplitItems.value
      .filter(item => (splitAssignment.value[item.splitKey] ?? 0) === pi)
      .reduce((s, item) => s + cart.parsePrecio(item.precio) * item.qty, 0)
  )
)

function cartQty(id: string): number {
  return cart.cart.find(c => c.id === id)?.qty ?? 0
}

function variantTotalQty(baseId: string): number {
  return cart.cart.filter(c => c.id.startsWith(baseId + '-c')).reduce((s, c) => s + c.qty, 0)
}

function addSimple(id: string) {
  const meta = itemsMap.value[id]
  if (!meta) return
  cart.addItem({ id, nombre: meta.nombre, precio: meta.precio ?? '$0', qty: 1, pagina: meta.pagina, seccion: meta.seccion, va_a_cocina: meta.va_a_cocina })
}

function removeSimple(id: string) {
  cart.removeItem(id)
}

// ── Variant picker ────────────────────────────────────
const vpBaseId  = ref<string | null>(null)
const vpVisible = ref(false)

function openVariantPicker(baseId: string) {
  vpBaseId.value = baseId
  vpVisible.value = true
}

function addVariant(colIdx: number) {
  const baseId = vpBaseId.value
  if (!baseId) return
  const meta = itemsMap.value[baseId]
  if (!meta?._columnas) return
  const id = `${baseId}-c${colIdx}`
  cart.addItem({ id, nombre: `${meta.nombre} (${meta._columnas[colIdx]})`, precio: meta.precios?.[colIdx] ?? '$0', qty: 1, pagina: meta.pagina, seccion: meta.seccion, va_a_cocina: meta.va_a_cocina })
}

function removeVariant(colIdx: number) {
  if (vpBaseId.value) cart.removeItem(`${vpBaseId.value}-c${colIdx}`)
}

function vpQty(colIdx: number): number {
  return vpBaseId.value ? cartQty(`${vpBaseId.value}-c${colIdx}`) : 0
}

// ── Note modal ────────────────────────────────────────
function openNote(idx: number) {
  noteIdx.value = idx
  noteText.value = cart.cart[idx]?.nota ?? ''
}

function saveNote() {
  if (noteIdx.value !== null) cart.setItemNote(noteIdx.value, noteText.value || null)
  noteIdx.value = null
}

function clearNote() {
  if (noteIdx.value !== null) cart.setItemNote(noteIdx.value, null)
  noteIdx.value = null
}

// ── Cambio modal ──────────────────────────────────────
function openCambio(item: PedidoItem) {
  cambioItem.value = item
  cambioText.value = ''
}

async function sendCambio() {
  if (!cambioItem.value || !cambioText.value.trim()) { showToast('Describí el cambio primero'); return }
  try { await cart.sendCambio(cambioItem.value, cambioText.value); showToast('Cambio enviado a cocina ✓') }
  catch { showToast('Error al enviar el cambio') }
  cambioItem.value = null
}

// ── Cancelacion ───────────────────────────────────────
async function confirmarCancelacion(item: PedidoItem) {
  if (!confirm(`¿Cancelar "${item.nombre}"? Se avisará a la cocina.`)) return
  try { await cart.sendCancelacion(item); showToast('Cancelación enviada a cocina ✓') }
  catch { showToast('Error al enviar la cancelación') }
}

// ── Send to kitchen ───────────────────────────────────
async function sendOrder() {
  if (sendingOrder.value) return
  sendingOrder.value = true
  try {
    const saved = await cart.saveOrder()
    const msg = cart.buildMsg()
    const url = `https://wa.me/${WA_NUMBER}?text=${encodeURIComponent(msg)}`
    const a = document.createElement('a')
    a.href = url; a.target = '_blank'; a.rel = 'noopener noreferrer'
    document.body.appendChild(a); a.click(); document.body.removeChild(a)
    fallbackMsg.value = msg
    showFallback.value = true
    cart.cartClear()
    showToast(saved ? '¡Pedido enviado y guardado! ✓' : '¡Pedido enviado! (sin conexión)')
  } catch { showToast('Error al guardar el pedido') }
  sendingOrder.value = false
}

async function copyFallback() {
  try { await navigator.clipboard.writeText(fallbackMsg.value); showToast('Copiado al portapapeles ✓') }
  catch { showToast('Seleccioná el texto y copialo manualmente') }
}

// ── Split billing ─────────────────────────────────────
function openSplit() {
  splitAssignment.value = {}
  splitPaid.value = Array(splitCount.value).fill(false) as boolean[]
  view.value = 'split'
}

function setSplitCount(n: number) {
  splitCount.value = n
  splitAssignment.value = {}
  splitPaid.value = Array(n).fill(false) as boolean[]
}

function toggleSplitItem(key: string) {
  splitAssignment.value = { ...splitAssignment.value, [key]: ((splitAssignment.value[key] ?? 0) + 1) % splitCount.value }
}

function paySplitPerson(personIdx: number) {
  splitPayingPerson.value = personIdx
  selectedPay.value = ''
  payVisible.value = true
}

// ── Send delivery WA ──────────────────────────────────
function sendDeliveryWA() {
  const { hh, mm } = timeBsAs()
  const s = cart.currentSession
  const allItems = [...cart.sessionItems, ...cart.cart]
  const lines = allItems.map(i => `${i.qty}× ${i.nombre}${i.nota ? ` _(${i.nota})_` : ''}`).join('\n')
  const subtotal = cart.grandTotal
  const totalConEnvio = subtotal + costoEnvio.value
  const envioLine = costoEnvio.value > 0 ? `\nEnvío: $${costoEnvio.value.toLocaleString('es-AR')}` : ''
  const msg = `🛵 *ENVÍO — ${hh}:${mm}*\n👤 ${s?.cliente_nombre ?? 'Cliente'}${s?.cliente_telefono ? `\n📞 ${s.cliente_telefono}` : ''}\n📍 ${s?.cliente_direccion ?? ''}${s?.cliente_referencia ? `\n📌 ${s.cliente_referencia}` : ''}\n━━━━━━━━━━━\n${lines || '(sin items aún)'}\n━━━━━━━━━━━${envioLine}\nTotal: $${totalConEnvio.toLocaleString('es-AR')}`
  const url = `https://wa.me/${WA_NUMBER}?text=${encodeURIComponent(msg)}`
  const a = document.createElement('a')
  a.href = url; a.target = '_blank'; a.rel = 'noopener noreferrer'
  document.body.appendChild(a); a.click(); document.body.removeChild(a)
}

// ── Payment modal ─────────────────────────────────────
const METODOS = [
  { id: 'efectivo',      label: 'Efectivo',     icon: '💵' },
  { id: 'debito',        label: 'Débito',        icon: '💳' },
  { id: 'credito',       label: 'Crédito',       icon: '🏦' },
  { id: 'transferencia', label: 'Transferencia', icon: '📱' },
  { id: 'mercadopago',   label: 'Mercado Pago',  icon: '🔵' },
  { id: 'pedidosya',     label: 'Pedidos Ya',    icon: '🛵' },
]

async function openPayment() {
  if (cart.cart.length > 0) {
    if (!confirm('Hay items pendientes de envío. ¿Cerrar la mesa igual?')) return
  }
  const sesionId = cart.currentSession?.id
  if (sesionId) {
    const { data: pending } = await supabase
      .from('pedidos').select('id').eq('sesion_id', sesionId).eq('estado', 'pendiente').limit(1)
    if (pending && pending.length > 0) {
      if (!confirm('Hay pedidos pendientes en cocina. ¿Cerrar la mesa igual?')) return
    }
  }
  selectedPay.value = cart.currentSession?.metodo_pago ?? ''
  payVisible.value = true
}

async function confirmPayment() {
  if (!selectedPay.value) return
  payVisible.value = false

  if (splitPayingPerson.value >= 0) {
    const personIdx = splitPayingPerson.value
    const monto = splitTotals.value[personIdx]
    splitPayingPerson.value = -1
    try {
      await cart.addPago(selectedPay.value, monto)
      splitPaid.value[personIdx] = true
      if (splitPaid.value.every(p => p)) {
        await cart.closeSessionOnly()
        showFallback.value = false
        await loadOpenSessions()
        view.value = 'mesas'
        showToast('Mesa cerrada ✓')
      } else {
        showToast(`Persona ${personIdx + 1} cobrada ✓`)
      }
    } catch { showToast('Error al registrar el pago') }
    return
  }

  await cart.closeSession(selectedPay.value, grandTotalAdjusted.value)
  showFallback.value = false
  await loadOpenSessions()
  view.value = 'mesas'
  showToast('Mesa cerrada ✓')
}

// ── Delivery form ─────────────────────────────────────
function openDeliveryForm() {
  delNombre.value = delTel.value = delDir.value = delRef.value = delMetodo.value = ''
  delFormVisible.value = true
}

async function confirmDelivery() {
  if (!delNombre.value.trim() || !delDir.value.trim()) { showToast('Completá al menos nombre y dirección'); return }
  delFormVisible.value = false
  const mesaKey = `envio_${Date.now()}`
  try {
    const { data: created, error } = await supabase
      .from('sesiones')
      .insert({
        mesa: mesaKey, estado: 'abierta', tipo: 'envio',
        moza_id: auth.currentUser?.id ?? null,
        moza_nombre: auth.currentUser?.nombre ?? null,
        cliente_nombre: delNombre.value.trim(),
        cliente_telefono: delTel.value.trim() || null,
        cliente_direccion: delDir.value.trim(),
        cliente_referencia: delRef.value.trim() || null,
        metodo_pago: delMetodo.value || null,
      })
      .select().single()
    if (error) throw error
    cart.mesaKey = mesaKey
    cart.currentSession = created as Sesion
    cart.sessionItems = []
    cart.cubiertos = 1
    cart.cart = []
    pageIdx.value = 0
    menuPages.value = getMenu()
    buildItemsMap()
    showFallback.value = false
    view.value = 'menu'
  } catch { showToast('Error al crear el envío') }
}

async function enterEnvio(sesion: Sesion) {
  cart.mesaKey = sesion.mesa
  cart.cartLoad()
  pageIdx.value = 0
  menuPages.value = getMenu()
  buildItemsMap()
  showFallback.value = false
  view.value = 'menu'
  try { await cart.openOrLoadSession(sesion.mesa) } catch { showToast('Sin conexión') }
}

// ── Para llevar form ──────────────────────────────────
function openLlevarForm() {
  llevarNombre.value = llevarTel.value = ''
  llevarFormVisible.value = true
}

async function confirmLlevar() {
  if (!llevarNombre.value.trim()) { showToast('Ingresá el nombre del cliente'); return }
  llevarFormVisible.value = false
  const mesaKey = `llevar_${Date.now()}`
  try {
    const { data: created, error } = await supabase
      .from('sesiones')
      .insert({
        mesa: mesaKey, estado: 'abierta', tipo: 'llevar',
        moza_id: auth.currentUser?.id ?? null,
        moza_nombre: auth.currentUser?.nombre ?? null,
        cliente_nombre: llevarNombre.value.trim(),
        cliente_telefono: llevarTel.value.trim() || null,
      })
      .select().single()
    if (error) throw error
    cart.mesaKey = mesaKey
    cart.currentSession = created as Sesion
    cart.sessionItems = []
    cart.cubiertos = 1
    cart.cart = []
    pageIdx.value = 0
    menuPages.value = getMenu()
    buildItemsMap()
    showFallback.value = false
    view.value = 'menu'
  } catch { showToast('Error al crear el pedido para llevar') }
}

async function enterLlevar(sesion: Sesion) {
  cart.mesaKey = sesion.mesa
  cart.cartLoad()
  pageIdx.value = 0
  menuPages.value = getMenu()
  buildItemsMap()
  showFallback.value = false
  view.value = 'menu'
  try { await cart.openOrLoadSession(sesion.mesa) } catch { showToast('Sin conexión') }
}

// ── Pedido listo notifications ────────────────────────
function setupListoNotifs() {
  listoChannel = supabase
    .channel('moza-listo-global')
    .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'pedidos' }, payload => {
      const nuevoEstado = payload.new?.estado as import('@/types/domain').EstadoPedido | undefined
      if (!nuevoEstado) return
      if (payload.new.sesion_id === cart.currentSession?.id) {
        cart.updatePedidoEstado(payload.new.id as string, nuevoEstado)
      }
      if (nuevoEstado === 'listo') {
        const label = findLabelForSesion(payload.new.sesion_id as string)
        if (label) showListoNotif(label)
      }
    })
    .subscribe()
}

function findLabelForSesion(sesionId: string): string | null {
  const isCajaOrDueno = auth.can('caja', 'dueno')
  if (cart.currentSession?.id === sesionId) return cart.mesaLabel
  for (const [key, sess] of Object.entries(openSessions.value)) {
    if (sess.id === sesionId) {
      if (isCajaOrDueno || sess.moza_id === auth.currentUser?.id) return mesaKeyLabel(key)
      return null
    }
  }
  const envio = deliverySessions.value.find(s => s.id === sesionId)
  if (envio && (isCajaOrDueno || envio.moza_id === auth.currentUser?.id))
    return envio.cliente_nombre ? `Envío — ${envio.cliente_nombre}` : 'Envío'
  const llevar = llevarSessions.value.find(s => s.id === sesionId)
  if (llevar && (isCajaOrDueno || llevar.moza_id === auth.currentUser?.id))
    return llevar.cliente_nombre ? `Para llevar — ${llevar.cliente_nombre}` : 'Para llevar'
  return null
}

function showListoNotif(label: string) {
  try {
    const Ctx = window.AudioContext || (window as unknown as Record<string, unknown>)['webkitAudioContext'] as typeof AudioContext
    const ctx = new Ctx()
    ;[660, 880].forEach((freq, i) => {
      const osc = ctx.createOscillator()
      const gain = ctx.createGain()
      osc.connect(gain); gain.connect(ctx.destination)
      osc.frequency.value = freq; osc.type = 'sine'
      gain.gain.setValueAtTime(0.3, ctx.currentTime + i * 0.18)
      gain.gain.exponentialRampToValueAtTime(0.001, ctx.currentTime + i * 0.18 + 0.28)
      osc.start(ctx.currentTime + i * 0.18)
      osc.stop(ctx.currentTime + i * 0.18 + 0.28)
    })
  } catch { /* silenced */ }
  listoText.value = '🍽️ Pedido listo — ' + label
  listoVisible.value = true
  if (listoTimer) clearTimeout(listoTimer)
  listoTimer = setTimeout(() => { listoVisible.value = false }, 9000)
}

// ── Entrega ítem por ítem ─────────────────────────────
async function marcarEntregado(item: PedidoItem) {
  const newQty = nextEntregadoQty(item.entregado_qty, item.qty)
  const { error } = await supabase.from('pedido_items').update({ entregado_qty: newQty }).eq('id', item.id)
  if (!error) item.entregado_qty = newQty
}

function setupEntregaRealtime(sesionId: string) {
  entregaChannel?.unsubscribe()
  entregaChannel = supabase
    .channel(`entrega-${sesionId}`)
    .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'pedido_items', filter: `sesion_id=eq.${sesionId}` }, payload => {
      const updated = payload.new as import('@/types/domain').PedidoItem
      const item = cart.sessionItems.find(i => i.id === updated.id)
      if (item) item.entregado_qty = updated.entregado_qty
    })
    .subscribe()
}

// ── Realtime sesiones grid ────────────────────────────
function setupRealtimeSesiones() {
  realtimeChannel = supabase
    .channel('sesiones-grid')
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'sesiones' }, () => {
      if (view.value === 'mesas') loadOpenSessions()
    })
    .on('postgres_changes', { event: 'UPDATE', schema: 'public', table: 'sesiones' }, () => {
      if (view.value === 'mesas') loadOpenSessions()
    })
    .subscribe()
}

// ── Toast ─────────────────────────────────────────────
function showToast(msg: string, ms = 2200) {
  toastMsg.value = msg
  if (toastTimer) clearTimeout(toastTimer)
  toastTimer = setTimeout(() => { toastMsg.value = '' }, ms)
}

// ── Lifecycle ─────────────────────────────────────────
onMounted(async () => {
  await loadConfig()
  await loadOpenSessions()
  setupListoNotifs()
  setupRealtimeSesiones()
})

onUnmounted(() => {
  realtimeChannel?.unsubscribe()
  listoChannel?.unsubscribe()
  entregaChannel?.unsubscribe()
  if (listoTimer) clearTimeout(listoTimer)
  if (toastTimer) clearTimeout(toastTimer)
})

async function doLogout() {
  await auth.logout()
  router.replace({ name: 'carta' })
}
</script>

<template>
  <div class="fixed inset-0 flex flex-col bg-dark text-white overflow-hidden">

    <!-- ── LISTO BANNER ── -->
    <Transition name="slide-down">
      <div v-if="listoVisible"
        class="fixed top-0 left-0 right-0 bg-green-800 text-white px-4 py-3.5 z-50
               flex items-center justify-between gap-3 text-sm font-bold shadow-lg">
        <span>{{ listoText }}</span>
        <button @click="listoVisible = false" class="text-white/70 text-xl leading-none bg-transparent border-none cursor-pointer">✕</button>
      </div>
    </Transition>

    <!-- ══════════════════════════════════════ MESAS ══ -->
    <template v-if="view === 'mesas'">
      <header class="bg-dark2 border-b border-gold/[.18] px-4 py-3 flex items-center gap-2 flex-shrink-0 min-h-[52px]">
        <span class="font-display text-[1.05rem] font-black text-gold tracking-[.06em]">Lescano's</span>
        <span class="text-[.6rem] text-gray-500 tracking-[.14em] ml-0.5">— Pedidos</span>
        <span class="flex-1 text-right text-[.6rem] text-gray-500">{{ auth.currentUser?.nombre }}</span>
        <button v-if="auth.can('dueno')" @click="router.push({ name: 'cocina' })"
          class="text-[.6rem] text-gold/60 border border-gold/20 px-2 py-1 rounded tracking-wider bg-transparent cursor-pointer">
          🍳 Cocina
        </button>
        <button v-if="auth.can('caja', 'dueno')" @click="router.push({ name: 'reportes' })"
          class="text-[.6rem] text-gold/60 border border-gold/20 px-2 py-1 rounded tracking-wider bg-transparent cursor-pointer">
          📊 Reportes
        </button>
        <button v-if="auth.can('dueno')" @click="router.push({ name: 'usuarios' })"
          class="text-[.6rem] text-gold/60 border border-gold/20 px-2 py-1 rounded tracking-wider bg-transparent cursor-pointer">
          👥 Usuarios
        </button>
        <button @click="doLogout"
          class="text-[.6rem] text-gold/70 border border-gold/30 px-2 py-1 rounded ml-1 tracking-wider bg-transparent cursor-pointer">
          Salir
        </button>
      </header>

      <div class="flex-1 overflow-y-auto">
        <div class="text-[.65rem] text-gray-500 tracking-[.18em] uppercase px-4 pt-3.5 pb-1.5">¿Para qué mesa?</div>
        <div class="grid grid-cols-3 gap-2.5 px-4 pb-5 pt-1.5">
          <button
            v-for="m in mesaItems" :key="m.key"
            @click="handleMesaClick(m.key)"
            :class="[
              'bg-dark2 border-2 rounded-xl text-center flex flex-col items-center justify-center gap-1 min-h-[78px] py-4 px-2 transition-colors cursor-pointer',
              m.active ? 'border-gold/70 bg-gold/[.07]' : 'border-gold/[.18]',
            ]"
          >
            <span class="font-display text-[1.35rem] font-black text-gold">{{ m.num }}</span>
            <span class="text-[.58rem] text-gray-500 tracking-[.12em] uppercase">Mesa</span>
            <template v-if="m.active">
              <span class="w-1.5 h-1.5 rounded-full bg-gold opacity-80"></span>
              <span v-if="m.moza" class="text-[.62rem] text-gray-400 max-w-[100px] truncate">{{ m.moza }}</span>
            </template>
          </button>
        </div>

        <!-- Para llevar -->
        <div class="text-[.65rem] text-gray-500 tracking-[.18em] uppercase px-4 pt-1 pb-1.5">🛍️ Para llevar</div>
        <div class="grid grid-cols-3 gap-2.5 px-4 pb-4">
          <button v-for="s in llevarSessions" :key="s.id" @click="enterLlevar(s)"
            class="bg-dark2 border-2 border-gold/60 bg-gold/[.05] rounded-xl py-4 px-2
                   text-center flex flex-col items-center justify-center gap-1 min-h-[78px] cursor-pointer">
            <span class="text-lg">🛍️</span>
            <span class="text-[.6rem] text-gold tracking-[.04em] uppercase truncate max-w-[80px]">{{ s.cliente_nombre || 'Cliente' }}</span>
            <span class="w-1.5 h-1.5 rounded-full bg-gold opacity-80"></span>
          </button>
          <button @click="openLlevarForm"
            class="bg-dark2 border-2 border-gold/[.18] rounded-xl py-4 px-2
                   text-center flex flex-col items-center justify-center gap-1 min-h-[78px] cursor-pointer">
            <span class="text-lg">🛍️</span>
            <span class="text-[.58rem] text-gray-500 tracking-[.1em] uppercase">Nuevo llevar</span>
          </button>
        </div>

        <!-- Envíos -->
        <div class="text-[.65rem] text-gray-500 tracking-[.18em] uppercase px-4 pt-1 pb-1.5">🛵 Envíos a domicilio</div>
        <div class="grid grid-cols-3 gap-2.5 px-4 pb-6">
          <button v-for="s in deliverySessions" :key="s.id" @click="enterEnvio(s)"
            class="bg-dark2 border-2 border-green-500/50 bg-green-500/[.05] rounded-xl py-4 px-2
                   text-center flex flex-col items-center justify-center gap-1 min-h-[78px] cursor-pointer">
            <span class="text-lg">🛵</span>
            <span class="text-[.6rem] text-green-400 tracking-[.04em] uppercase">{{ s.cliente_nombre || 'Envío' }}</span>
            <span class="w-1.5 h-1.5 rounded-full bg-green-400"></span>
          </button>
          <button @click="openDeliveryForm"
            class="bg-dark2 border-2 border-gold/[.18] rounded-xl py-4 px-2
                   text-center flex flex-col items-center justify-center gap-1 min-h-[78px] cursor-pointer">
            <span class="text-lg">🛵</span>
            <span class="text-[.58rem] text-gray-500 tracking-[.1em] uppercase">Nuevo envío</span>
          </button>
        </div>
      </div>
    </template>

    <!-- ════════════════════════════════════════ MENU ══ -->
    <template v-else-if="view === 'menu'">
      <header class="bg-dark2 border-b border-gold/[.18] px-4 py-3 flex items-center gap-2 flex-shrink-0 min-h-[52px]">
        <button @click="backToMesas" class="text-gold text-2xl leading-none px-1 pr-2 bg-transparent border-none cursor-pointer">‹</button>
        <span class="flex-1 text-[.95rem] font-bold text-gold">{{ cart.mesaLabel }}</span>
        <div class="flex items-center gap-1 flex-shrink-0 mr-1.5">
          <button @click="cart.setCubiertos(cart.cubiertos - 1)"
            class="w-[22px] h-[22px] rounded-full border-[1.5px] border-gold/40 text-gold text-base leading-none flex items-center justify-center bg-transparent cursor-pointer">−</button>
          <div class="text-center leading-tight">
            <div class="text-[.78rem] font-bold text-white min-w-[14px]">{{ cart.cubiertos }}</div>
            <div class="text-[.5rem] text-gray-500 tracking-[.08em]">cub</div>
          </div>
          <button @click="cart.setCubiertos(cart.cubiertos + 1)"
            class="w-[22px] h-[22px] rounded-full border-[1.5px] border-gold/40 text-gold text-base leading-none flex items-center justify-center bg-transparent cursor-pointer">+</button>
        </div>
        <div class="bg-gold text-dark text-[.7rem] font-bold min-w-[26px] h-[26px] rounded-full flex items-center justify-center px-1.5">
          {{ cart.cartCount }}
        </div>
      </header>

      <!-- Page tabs -->
      <div class="flex overflow-x-auto border-b border-gold/[.18] flex-shrink-0" style="-webkit-overflow-scrolling:touch;scrollbar-width:none">
        <button v-for="(page, i) in menuPages" :key="i" @click="pageIdx = i"
          :class="[
            'px-4 py-2.5 flex-shrink-0 text-[.72rem] font-bold tracking-[.04em] whitespace-nowrap border-b-2 -mb-px transition-colors bg-transparent cursor-pointer',
            i === pageIdx ? 'text-gold border-gold' : 'text-gray-500 border-transparent',
          ]">
          {{ page.titulo }}
        </button>
      </div>

      <!-- Menu items -->
      <div class="flex-1 overflow-y-auto pb-20">
        <template v-if="currentPage">
          <template v-if="currentPage.tipo === 'promos'">
            <div class="bg-gold/[.07] border-b border-gold/[.18] px-4 py-2 flex items-center gap-2 sticky top-0 z-10" style="backdrop-filter:blur(6px)">
              <span>🎉</span>
              <span class="text-[.75rem] font-bold text-gold tracking-[.08em] uppercase">{{ currentPage.subtitulo || 'PROMOS' }}</span>
            </div>
            <div v-for="(item, ii) in (currentPage.items || [])" :key="ii"
              class="flex items-center px-4 py-3 border-b border-white/[.05] gap-3">
              <div class="flex-1 min-w-0">
                <div class="text-[.9rem] font-bold text-white">{{ item.nombre }}</div>
              </div>
              <div v-if="item.precio && item.precio !== '$0'" class="font-display text-[.8rem] text-gold whitespace-nowrap flex-shrink-0">{{ item.precio }}</div>
              <div class="flex items-center gap-2 flex-shrink-0">
                <template v-if="cartQty(`promo-${pageIdx}-${ii}`) > 0">
                  <button @click="removeSimple(`promo-${pageIdx}-${ii}`)"
                    class="w-9 h-9 border-[1.5px] border-gold/35 rounded-full text-gold text-xl flex items-center justify-center bg-transparent cursor-pointer">−</button>
                  <span class="text-[.9rem] font-bold text-white min-w-[18px] text-center">{{ cartQty(`promo-${pageIdx}-${ii}`) }}</span>
                </template>
                <button @click="addSimple(`promo-${pageIdx}-${ii}`)"
                  class="w-9 h-9 border-[1.5px] border-gold/35 rounded-full text-gold text-xl flex items-center justify-center bg-transparent cursor-pointer">+</button>
              </div>
            </div>
          </template>

          <template v-else>
            <template v-for="(sec, si) in (currentPage.secciones || [])" :key="si">
              <div class="bg-gold/[.07] border-b border-gold/[.18] px-4 py-2 flex items-center gap-2 sticky top-0 z-10" style="backdrop-filter:blur(6px)">
                <span>{{ sec.emoji }}</span>
                <span class="text-[.75rem] font-bold text-gold tracking-[.08em] uppercase">{{ sec.titulo }}</span>
                <span v-if="sec.nota" class="text-[.62rem] text-gray-500 ml-auto italic">{{ sec.nota }}</span>
              </div>
              <div v-for="(item, ii) in sec.items" :key="ii"
                class="flex items-center px-4 py-3 border-b border-white/[.05] gap-3">
                <div class="flex-1 min-w-0">
                  <div class="text-[.9rem] font-bold text-white leading-tight">{{ item.nombre }}</div>
                  <div v-if="item.desc" class="text-[.68rem] text-gray-500 italic mt-0.5 leading-snug">{{ item.desc }}</div>
                </div>
                <!-- Multi-column variants -->
                <template v-if="sec.columnas">
                  <div class="flex gap-1 flex-shrink-0 items-end">
                    <div v-for="(col, ci) in sec.columnas" :key="ci" class="flex flex-col items-center min-w-[44px]">
                      <div class="text-[.48rem] text-gray-500 whitespace-nowrap text-center leading-tight tracking-[.03em]">{{ col }}</div>
                      <div class="font-display text-[.78rem] text-gold font-bold whitespace-nowrap text-center">{{ (item.precios && item.precios[ci]) || '$0' }}</div>
                    </div>
                  </div>
                  <div class="flex items-center gap-2 flex-shrink-0">
                    <span v-if="variantTotalQty(`p${pageIdx}s${si}i${ii}`) > 0"
                      class="text-[.75rem] font-bold text-gold min-w-[20px] text-center">
                      {{ variantTotalQty(`p${pageIdx}s${si}i${ii}`) }}×
                    </span>
                    <button @click="openVariantPicker(`p${pageIdx}s${si}i${ii}`)"
                      class="w-9 h-9 border-[1.5px] border-gold/35 rounded-full text-gold text-xl flex items-center justify-center bg-transparent cursor-pointer">+</button>
                  </div>
                </template>
                <!-- Simple -->
                <template v-else>
                  <div v-if="(item.precio || item.precios?.[0]) && (item.precio || item.precios?.[0]) !== '$0'"
                    class="font-display text-[.8rem] text-gold whitespace-nowrap flex-shrink-0">
                    {{ item.precio || item.precios?.[0] }}
                  </div>
                  <div class="flex items-center gap-2 flex-shrink-0">
                    <template v-if="cartQty(`p${pageIdx}s${si}i${ii}`) > 0">
                      <button @click="removeSimple(`p${pageIdx}s${si}i${ii}`)"
                        class="w-9 h-9 border-[1.5px] border-gold/35 rounded-full text-gold text-xl flex items-center justify-center bg-transparent cursor-pointer">−</button>
                      <span class="text-[.9rem] font-bold text-white min-w-[18px] text-center">{{ cartQty(`p${pageIdx}s${si}i${ii}`) }}</span>
                    </template>
                    <button @click="addSimple(`p${pageIdx}s${si}i${ii}`)"
                      class="w-9 h-9 border-[1.5px] border-gold/35 rounded-full text-gold text-xl flex items-center justify-center bg-transparent cursor-pointer">+</button>
                  </div>
                </template>
              </div>
            </template>
          </template>
        </template>
      </div>

      <!-- Footer -->
      <div class="fixed bottom-0 left-0 right-0 px-4 pb-[18px] pt-2.5 pointer-events-none">
        <button
          @click="view = 'resumen'"
          :disabled="cart.cartCount === 0 && cart.sessionItems.length === 0"
          class="w-full py-3.5 bg-gold text-dark font-bold text-[.95rem] rounded-[10px] tracking-[.04em]
                 disabled:bg-gold/22 disabled:text-black/35 active:opacity-80 transition-opacity pointer-events-auto"
        >
          <span v-if="cart.cartCount > 0">Ver resumen · {{ cart.cartCount }} item{{ cart.cartCount !== 1 ? 's' : '' }}</span>
          <span v-else-if="cart.sessionItems.length > 0">Ver cuenta de la mesa</span>
          <span v-else>Ver resumen · 0 items</span>
        </button>
      </div>
    </template>

    <!-- ══════════════════════════════════════ RESUMEN ══ -->
    <template v-else-if="view === 'resumen'">
      <header class="bg-dark2 border-b border-gold/[.18] px-4 py-3 flex items-center gap-2 flex-shrink-0 min-h-[52px]">
        <button @click="view = 'menu'" class="text-gold text-2xl leading-none px-1 pr-2 bg-transparent border-none cursor-pointer">‹</button>
        <span class="flex-1 text-[.95rem] font-bold text-gold">{{ cart.mesaLabel }}</span>
        <button v-if="cart.cart.length + cart.sessionItems.length > 0" @click="openSplit"
          class="text-[.65rem] text-gold/60 border border-gold/25 px-2.5 py-1 rounded tracking-wider bg-transparent cursor-pointer flex-shrink-0">
          Dividir
        </button>
      </header>

      <div class="flex-1 overflow-y-auto pb-44">
        <div v-if="cart.cart.length === 0 && cart.sessionItems.length === 0"
          class="p-10 text-center text-gray-500 text-[.85rem] leading-relaxed">
          No hay items en esta cuenta.<br>Agregá productos desde el menú.
        </div>
        <template v-else>
          <div v-if="cart.cart.length > 0">
            <div v-if="sessionItemsDisplay.length > 0"
              class="px-4 pt-2.5 pb-1 text-[.55rem] text-gray-500 tracking-[.18em] uppercase">Pendiente de envío</div>
            <div v-for="(item, idx) in cart.cart" :key="idx"
              class="flex items-center px-4 py-3.5 border-b border-white/[.05] gap-3">
              <div class="bg-gold text-dark text-[.75rem] font-bold rounded-[6px] px-2 py-0.5 flex-shrink-0">×{{ item.qty }}</div>
              <div class="flex-1 min-w-0">
                <div class="text-[.9rem] text-white font-medium">{{ item.nombre }}</div>
                <div v-if="item.nota" class="text-[.65rem] text-gray-500 italic mt-0.5">📝 {{ item.nota }}</div>
                <button @click="openNote(idx)"
                  class="text-[.6rem] text-gold/50 mt-0.5 border-none bg-transparent p-0 cursor-pointer inline-block">
                  {{ item.nota ? '✎ editar nota' : '+ nota' }}
                </button>
              </div>
              <div v-if="item.precio && item.precio !== '$0'" class="font-display text-[.82rem] text-gold">{{ item.precio }}</div>
              <button @click="cart.removeCartEntry(idx)"
                class="text-red-400/45 text-[1.1rem] leading-none flex-shrink-0 bg-transparent border-none cursor-pointer px-0.5">✕</button>
            </div>
          </div>

          <div v-if="sessionItemsDisplay.length > 0">
            <div v-if="cart.cart.length > 0"
              class="px-4 pt-2.5 pb-1 text-[.55rem] text-gray-500 tracking-[.18em] uppercase">Ya enviado</div>

            <!-- Banner todo entregado -->
            <div v-if="todoEntregado"
              class="mx-4 my-2 px-3 py-2 rounded-[10px] bg-green-500/[.12] border border-green-500/30 flex items-center gap-2">
              <span class="text-green-400 text-base">✓</span>
              <span class="text-[.78rem] text-green-400 font-bold">Todo entregado a la mesa</span>
            </div>

            <!-- Grupos por pedido con badge de estado -->
            <template v-for="group in sessionPedidoGroups" :key="group.pedido.id">
              <!-- Cabecera del grupo -->
              <div class="flex items-center gap-2 px-4 pt-2.5 pb-0.5">
                <span class="text-[.52rem] text-gray-600 tracking-[.12em] uppercase flex-1">
                  Enviado a las {{ new Date(group.pedido.created_at).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' }) }}
                </span>
                <span v-if="group.pedido.tipo === 'barra'"
                  class="text-[.52rem] font-bold tracking-[.08em] px-1.5 py-0.5 rounded-full bg-blue-500/15 text-blue-400">
                  🍺 Barra
                </span>
                <span v-else-if="group.pedido.estado === 'listo'"
                  class="text-[.52rem] font-bold tracking-[.08em] px-1.5 py-0.5 rounded-full bg-green-500/15 text-green-400">
                  ✓ Listo
                </span>
                <span v-else-if="group.pedido.estado === 'en_preparacion'"
                  class="text-[.52rem] font-bold tracking-[.08em] px-1.5 py-0.5 rounded-full bg-[#E89500]/15 text-[#E89500]">
                  🍳 Preparando
                </span>
                <span v-else
                  class="text-[.52rem] font-bold tracking-[.08em] px-1.5 py-0.5 rounded-full bg-gold/12 text-gold/70">
                  En cocina
                </span>
              </div>

              <!-- Items del grupo -->
              <div v-for="item in group.items" :key="item.id"
                :class="['flex items-center px-4 py-3 border-b border-white/[.05] gap-3',
                  cancelledNames.has(item.nombre) ? 'opacity-35' : '']">
                <div class="bg-gold/40 text-black/50 text-[.75rem] font-bold rounded-[6px] px-2 py-0.5 flex-shrink-0">×{{ item.qty }}</div>
                <div class="flex-1 min-w-0">
                  <div :class="['text-[.9rem] font-medium', cancelledNames.has(item.nombre) ? 'text-red-400/70 line-through' : 'text-white/80']">
                    {{ item.nombre }}
                  </div>
                  <div v-if="cancelledNames.has(item.nombre)"
                    class="text-[.6rem] text-red-400/60 tracking-[.06em] uppercase mt-0.5">Cancelado</div>
                  <div v-else-if="item.nota" class="text-[.65rem] text-gray-500 italic mt-0.5">📝 {{ item.nota }}</div>
                </div>
                <div v-if="item.precio && item.precio !== '$0' && !cancelledNames.has(item.nombre)"
                  class="font-display text-[.82rem] text-gold">{{ item.precio }}</div>

                <!-- Botón de entrega -->
                <button v-if="!cancelledNames.has(item.nombre)"
                  @click.stop="marcarEntregado(item)"
                  :class="[
                    'flex-shrink-0 min-w-[44px] text-center text-[.72rem] font-bold px-2 py-1.5 rounded-lg border cursor-pointer transition-colors',
                    entregadoStatus(item.entregado_qty, item.qty) === 'none'    ? 'border-white/15 text-white/30 bg-transparent' :
                    entregadoStatus(item.entregado_qty, item.qty) === 'full'    ? 'border-green-500/50 text-green-400 bg-green-500/[.1]' :
                                                                                  'border-gold/50 text-gold bg-gold/[.08]'
                  ]">
                  {{ entregadoStatus(item.entregado_qty, item.qty) === 'full' ? '✓' : `${item.entregado_qty}/${item.qty}` }}
                </button>

                <div v-if="!cancelledNames.has(item.nombre)" class="flex gap-1 flex-shrink-0">
                  <button @click.stop="openCambio(item)"
                    class="border border-[#E89500]/50 text-[#E89500] text-[.62rem] px-2.5 py-1 rounded-md cursor-pointer tracking-[.03em] whitespace-nowrap bg-transparent">
                    ⚠ Cambiar
                  </button>
                  <button @click.stop="confirmarCancelacion(item)"
                    class="border border-red-400/40 text-red-400 text-[.62rem] px-2.5 py-1 rounded-md cursor-pointer tracking-[.03em] whitespace-nowrap bg-transparent">
                    ✕ Cancelar
                  </button>
                </div>
              </div>
            </template>
          </div>

          <div v-if="cart.mesaKey?.startsWith('envio_') && costoEnvio > 0"
            class="flex justify-between items-center px-4 py-2.5 border-t border-white/[.05]">
            <span class="text-[.82rem] text-gray-500">🛵 Costo de envío</span>
            <span class="font-display text-[.9rem] text-gold">${{ costoEnvio.toLocaleString('es-AR') }}</span>
          </div>
          <div v-if="cart.hasRealPrices"
            class="flex justify-between items-center px-4 py-3.5 border-t border-gold/[.22]">
            <span class="text-[.85rem] text-gray-500 font-bold">{{ sessionItemsDisplay.length > 0 ? 'Total de la cuenta' : 'Total estimado' }}</span>
            <span class="font-display text-[1.1rem] font-bold text-gold">${{ grandTotalAdjusted.toLocaleString('es-AR') }}</span>
          </div>
        </template>

        <!-- Fallback WA text -->
        <div v-if="showFallback" class="px-4 pb-2 mt-2">
          <textarea :value="fallbackMsg" readonly
            class="w-full h-[72px] bg-dark2 border border-gold/[.18] text-gray-400 text-[.78rem] p-2 rounded-lg resize-none font-mono"></textarea>
          <button @click="copyFallback"
            class="w-full mt-1.5 py-2.5 text-gold border-[1.5px] border-gold text-[.85rem] font-bold rounded-lg tracking-[.04em] bg-transparent cursor-pointer">
            Copiar texto
          </button>
        </div>
      </div>

      <!-- Footer -->
      <div class="fixed bottom-0 left-0 right-0 px-4 pb-[18px] pt-2.5 bg-gradient-to-t from-dark via-dark/80 to-transparent">
        <button @click="sendOrder" :disabled="sendingOrder || cart.cartCount === 0"
          class="w-full py-3.5 bg-[#2a6f2a] text-white font-bold text-[.95rem] rounded-[10px] tracking-[.04em]
                 disabled:opacity-45 active:opacity-80 transition-opacity cursor-pointer">
          <span v-if="sendingOrder">Guardando...</span>
          <span v-else-if="cart.cartCount > 0">📲 Enviar a cocina ({{ cart.cartCount }} items)</span>
          <span v-else>📲 Sin items pendientes</span>
        </button>
        <button v-if="cart.mesaKey?.startsWith('envio_')" @click="sendDeliveryWA"
          class="w-full mt-2 py-3 text-green-400 border-[1.5px] border-green-400/60 text-[.85rem] font-bold rounded-[10px] tracking-[.04em] bg-transparent cursor-pointer">
          🛵 Enviar al cadete (WhatsApp)
        </button>
        <button v-if="showFallback" @click="() => { showFallback = false; cart.clearState(); loadOpenSessions(); view = 'mesas' }"
          class="w-full mt-2 py-2.5 text-gold border-[1.5px] border-gold/40 text-[.82rem] font-bold rounded-[10px] tracking-[.04em] bg-transparent cursor-pointer">
          ← Volver a mesas
        </button>
        <button @click="openPayment"
          class="w-full mt-2 py-2.5 text-red-400/70 border-[1.5px] border-red-500/30 text-[.82rem] font-bold rounded-[10px] tracking-[.04em] bg-transparent cursor-pointer">
          Cerrar mesa
        </button>
      </div>
    </template>

    <!-- ══════════════════════════════════════ SPLIT ══ -->
    <template v-else-if="view === 'split'">
      <header class="bg-dark2 border-b border-gold/[.18] px-4 py-3 flex items-center gap-2 flex-shrink-0 min-h-[52px]">
        <button @click="view = 'resumen'" class="text-gold text-2xl leading-none px-1 pr-2 bg-transparent border-none cursor-pointer">‹</button>
        <span class="flex-1 text-[.95rem] font-bold text-gold">Dividir — {{ cart.mesaLabel }}</span>
        <div class="flex gap-1">
          <button v-for="n in [2, 3, 4]" :key="n" @click="setSplitCount(n)"
            :class="['text-[.65rem] font-bold px-2.5 py-1 rounded border cursor-pointer transition-colors',
              splitCount === n ? 'bg-gold text-dark border-gold' : 'text-gold/50 border-gold/20 bg-transparent']">
            {{ n }}p
          </button>
        </div>
      </header>

      <div class="text-[.55rem] text-gray-500 tracking-[.14em] uppercase text-center py-2 px-4 flex-shrink-0">
        Tocá un ítem para asignarlo a otra persona
      </div>

      <div class="flex-1 overflow-y-auto pb-[200px]">
        <div v-if="allSplitItems.length === 0" class="p-10 text-center text-gray-500 text-[.85rem]">
          No hay ítems en esta cuenta.
        </div>
        <div v-for="item in allSplitItems" :key="item.splitKey"
          @click="toggleSplitItem(item.splitKey)"
          class="flex items-center px-4 py-3 border-b border-white/[.05] gap-3 cursor-pointer active:bg-white/[.04] select-none">
          <div :class="[
            'min-w-[28px] h-7 px-1.5 rounded-[6px] text-[.7rem] font-black flex items-center justify-center flex-shrink-0',
            (splitAssignment[item.splitKey] ?? 0) === 0 ? 'bg-gold text-dark' :
            (splitAssignment[item.splitKey] ?? 0) === 1 ? 'bg-[#4C9EC9] text-white' :
            (splitAssignment[item.splitKey] ?? 0) === 2 ? 'bg-[#4CAD6A] text-white' :
                                                           'bg-[#C94C6B] text-white'
          ]">P{{ (splitAssignment[item.splitKey] ?? 0) + 1 }}</div>
          <div class="text-[.68rem] font-bold rounded-[5px] px-1.5 py-0.5 bg-white/[.07] text-gray-400 flex-shrink-0">×{{ item.qty }}</div>
          <div class="flex-1 min-w-0">
            <div class="text-[.88rem] text-white font-medium truncate">{{ item.nombre }}</div>
            <div v-if="item.nota" class="text-[.62rem] text-gray-500 italic">📝 {{ item.nota }}</div>
          </div>
          <div v-if="item.precio && item.precio !== '$0'" class="font-display text-[.8rem] text-gold whitespace-nowrap flex-shrink-0">{{ item.precio }}</div>
        </div>
      </div>

      <!-- Per-person pay buttons -->
      <div class="fixed bottom-0 left-0 right-0 px-4 pb-[18px] pt-3 bg-gradient-to-t from-dark via-dark/90 to-transparent">
        <div v-for="(total, idx) in splitTotals" :key="idx" class="mb-2">
          <div v-if="splitPaid[idx]"
            :class="[
              'w-full py-3 rounded-[10px] text-[.88rem] font-bold text-center tracking-[.04em]',
              idx === 0 ? 'bg-gold/[.08] text-gold/40 border border-gold/15' :
              idx === 1 ? 'bg-[#4C9EC9]/[.08] text-[#4C9EC9]/50 border border-[#4C9EC9]/15' :
              idx === 2 ? 'bg-[#4CAD6A]/[.08] text-[#4CAD6A]/50 border border-[#4CAD6A]/15' :
                          'bg-[#C94C6B]/[.08] text-[#C94C6B]/50 border border-[#C94C6B]/15'
            ]">✓ Persona {{ idx + 1 }} cobrada</div>
          <button v-else @click="paySplitPerson(idx)"
            :disabled="total === 0"
            :class="[
              'w-full py-3.5 rounded-[10px] text-[.88rem] font-bold tracking-[.04em] border-none cursor-pointer transition-opacity disabled:opacity-30',
              idx === 0 ? 'bg-gold text-dark' :
              idx === 1 ? 'bg-[#4C9EC9] text-white' :
              idx === 2 ? 'bg-[#4CAD6A] text-white' :
                          'bg-[#C94C6B] text-white'
            ]">
            Cobrar Persona {{ idx + 1 }}<span v-if="total > 0"> — ${{ total.toLocaleString('es-AR') }}</span>
          </button>
        </div>
      </div>
    </template>

    <!-- ══════════════════════════════════ VARIANT PICKER ══ -->
    <Transition name="sheet">
      <div v-if="vpVisible" class="fixed inset-0 bg-black/65 z-50 flex items-end" @click.self="() => { vpVisible = false }">
        <div class="w-full bg-dark2 rounded-t-[18px] border-t border-gold/25 pt-2 pb-8">
          <div class="w-10 h-1 rounded-full bg-white/15 mx-auto mb-3.5"></div>
          <div v-if="vpBaseId" class="text-[.9rem] font-bold text-white text-center px-5 pb-1">
            {{ itemsMap[vpBaseId]?.nombre }}
          </div>
          <div class="text-[.6rem] text-gray-500 tracking-[.14em] text-center px-5 pb-2.5 border-b border-white/[.06] mb-1">¿CÓMO LO QUIERE?</div>
          <div class="px-3" v-if="vpBaseId && itemsMap[vpBaseId]?._columnas">
            <div v-for="(col, ci) in itemsMap[vpBaseId]._columnas" :key="ci"
              class="flex items-center gap-2.5 px-3.5 py-3 rounded-[10px] my-1.5 bg-white/[.04] border border-gold/[.12]">
              <span class="flex-1 text-[.9rem] font-bold text-white">{{ col }}</span>
              <span v-if="itemsMap[vpBaseId].precios?.[ci] && itemsMap[vpBaseId].precios?.[ci] !== '$0'"
                class="font-display text-[.82rem] text-gold whitespace-nowrap min-w-[52px] text-right">{{ itemsMap[vpBaseId].precios?.[ci] }}</span>
              <div class="flex items-center gap-2 flex-shrink-0">
                <button @click="removeVariant(ci)" :disabled="vpQty(ci) === 0"
                  class="w-[34px] h-[34px] rounded-full border-[1.5px] border-gold/45 text-gold text-xl flex items-center justify-center bg-transparent cursor-pointer disabled:opacity-20 disabled:cursor-default">−</button>
                <span class="text-[.9rem] font-bold text-white min-w-[18px] text-center">{{ vpQty(ci) }}</span>
                <button @click="addVariant(ci)"
                  class="w-[34px] h-[34px] rounded-full border-[1.5px] border-gold/45 text-gold text-xl flex items-center justify-center bg-transparent cursor-pointer">+</button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Transition>

    <!-- ══════════════════════════════════════ NOTE MODAL ══ -->
    <Transition name="sheet">
      <div v-if="noteIdx !== null" class="fixed inset-0 bg-black/65 z-[70] flex items-end" @click.self="noteIdx = null">
        <div class="w-full bg-dark2 rounded-t-[18px] border-t border-gold/25 pt-2">
          <div class="w-10 h-1 rounded-full bg-white/15 mx-auto mb-3.5"></div>
          <div class="text-[.88rem] font-bold text-white text-center px-5 pb-1">{{ noteIdx !== null ? cart.cart[noteIdx]?.nombre : '' }}</div>
          <div class="text-[.58rem] text-gray-500 tracking-[.16em] text-center px-5 pb-2.5 border-b border-white/[.06]">NOTA PARA COCINA</div>
          <textarea v-model="noteText" placeholder="Ej: sin cebolla, bien cocido, sin sal..."
            class="block w-[calc(100%-28px)] mx-3.5 mt-3.5 bg-white/[.06] border border-gold/[.18] text-white text-[.9rem] px-3 py-2.5 rounded-[10px] resize-none h-[76px] focus:outline-none focus:border-gold/50"></textarea>
          <button @click="saveNote"
            class="block w-[calc(100%-28px)] mx-3.5 mt-2.5 py-3.5 bg-gold text-dark font-bold text-[.9rem] rounded-[10px] tracking-[.04em] cursor-pointer border-none">Guardar nota</button>
          <button @click="clearNote"
            class="block w-[calc(100%-28px)] mx-3.5 mt-2 mb-7 py-2.5 text-white/30 border border-white/10 rounded-lg text-[.8rem] bg-transparent tracking-[.04em] cursor-pointer">Quitar nota</button>
        </div>
      </div>
    </Transition>

    <!-- ══════════════════════════════════════ CAMBIO MODAL ══ -->
    <Transition name="sheet">
      <div v-if="cambioItem" class="fixed inset-0 bg-black/72 z-[75] flex items-end" @click.self="cambioItem = null">
        <div class="w-full bg-dark2 rounded-t-[18px] border-t-2 border-[#E89500]/50 pt-2">
          <div class="w-10 h-1 rounded-full bg-white/15 mx-auto mb-3.5"></div>
          <div class="text-[.58rem] text-[#E89500] tracking-[.2em] uppercase text-center pb-0.5">⚠ Cambio a cocina</div>
          <div class="text-[.92rem] font-bold text-white text-center px-5 pb-3 border-b border-white/[.06]">
            {{ cambioItem.nombre }}{{ cambioItem.nota ? ' — ' + cambioItem.nota : '' }}
          </div>
          <textarea v-model="cambioText" placeholder="Describí el cambio — ej: cambiar por Tweety con papas, sin cebolla..."
            class="block w-[calc(100%-28px)] mx-3.5 mt-3.5 bg-white/[.06] border border-[#E89500]/30 text-white text-[.9rem] px-3 py-2.5 rounded-[10px] resize-none h-[76px] focus:outline-none focus:border-[#E89500]/60"></textarea>
          <button @click="sendCambio"
            class="block w-[calc(100%-28px)] mx-3.5 mt-2.5 py-3.5 bg-[#E89500] text-[#111] font-bold text-[.9rem] rounded-[10px] tracking-[.04em] cursor-pointer border-none">Enviar cambio a cocina</button>
          <button @click="cambioItem = null"
            class="block w-[calc(100%-28px)] mx-3.5 mt-2 mb-7 py-2.5 text-white/30 border border-white/10 rounded-lg text-[.8rem] bg-transparent tracking-[.04em] cursor-pointer">Cancelar</button>
        </div>
      </div>
    </Transition>

    <!-- ══════════════════════════════════════ PAYMENT MODAL ══ -->
    <Transition name="sheet">
      <div v-if="payVisible" class="fixed inset-0 bg-black/75 z-[60] flex items-end" @click.self="payVisible = false">
        <div class="w-full bg-[#1a1a1a] rounded-t-[22px] border-t border-gold/30 pt-2 pb-9 max-h-[92vh] overflow-y-auto">
          <div class="w-10 h-1 rounded-full bg-white/15 mx-auto mb-4"></div>
          <div class="font-display text-[1rem] font-black text-gold text-center tracking-[.06em] px-5 pb-1">
            {{ splitPayingPerson >= 0 ? `Persona ${splitPayingPerson + 1}` : 'Cerrar mesa' }}
          </div>
          <div class="text-[.6rem] text-gray-500 text-center tracking-[.12em] pb-3 border-b border-white/[.06]">{{ cart.mesaLabel }}</div>
          <div v-if="splitPayingPerson < 0" class="flex items-center justify-between px-5 py-3 border-b border-white/[.06]">
            <span class="text-[.6rem] text-gray-500 tracking-[.14em] uppercase">Cubiertos</span>
            <div class="flex items-center gap-4">
              <button @click="cart.setCubiertos(cart.cubiertos - 1)"
                class="w-8 h-8 rounded-full border-[1.5px] border-gold/40 text-gold text-xl flex items-center justify-center bg-transparent cursor-pointer">−</button>
              <span class="font-display text-[1.4rem] font-black text-gold min-w-[28px] text-center">{{ cart.cubiertos }}</span>
              <button @click="cart.setCubiertos(cart.cubiertos + 1)"
                class="w-8 h-8 rounded-full border-[1.5px] border-gold/40 text-gold text-xl flex items-center justify-center bg-transparent cursor-pointer">+</button>
            </div>
          </div>
          <div class="text-center px-5 py-3.5 pb-2.5">
            <div class="text-[.6rem] text-gray-500 tracking-[.15em] uppercase">
              {{ splitPayingPerson >= 0 ? 'Monto a cobrar' : 'Total de la cuenta' }}
            </div>
            <div class="font-display text-[2rem] font-black text-gold leading-tight">
              {{ splitPayingPerson >= 0
                  ? (splitTotals[splitPayingPerson] > 0 ? `$${splitTotals[splitPayingPerson].toLocaleString('es-AR')}` : '—')
                  : (grandTotalAdjusted > 0 ? `$${grandTotalAdjusted.toLocaleString('es-AR')}` : '—') }}
            </div>
          </div>
          <div class="text-[.58rem] text-gray-500 tracking-[.14em] uppercase px-5 py-2">¿Cómo paga la mesa?</div>
          <div class="grid grid-cols-3 gap-2 px-3.5 pb-3.5">
            <button v-for="m in METODOS" :key="m.id" @click="selectedPay = m.id"
              :class="[
                'border-[1.5px] rounded-xl py-3.5 px-2 text-center flex flex-col items-center gap-1 transition-colors cursor-pointer',
                selectedPay === m.id ? 'border-gold bg-gold/[.12] bg-white/[.04]' : 'border-gold/15 bg-white/[.04]',
              ]">
              <div class="text-[1.4rem] leading-none">{{ m.icon }}</div>
              <div :class="['text-[.6rem] font-bold tracking-[.03em] text-center', selectedPay === m.id ? 'text-gold' : 'text-gray-300']">{{ m.label }}</div>
            </button>
          </div>
          <button @click="confirmPayment" :disabled="!selectedPay"
            class="block w-[calc(100%-28px)] mx-3.5 mt-1 py-3.5 bg-gold text-dark font-bold text-[.95rem] rounded-[10px] tracking-[.04em] cursor-pointer border-none
                   disabled:bg-gold/22 disabled:text-black/35 disabled:cursor-default">Confirmar cierre</button>
          <button @click="payVisible = false"
            class="block w-[calc(100%-28px)] mx-3.5 mt-2 py-2.5 text-white/35 border border-white/10 rounded-lg text-[.82rem] bg-transparent tracking-[.04em] cursor-pointer">Cancelar</button>
        </div>
      </div>
    </Transition>

    <!-- ══════════════════════════════════════ DELIVERY FORM ══ -->
    <Transition name="sheet">
      <div v-if="delFormVisible" class="fixed inset-0 bg-black/72 z-[80] flex items-end" @click.self="delFormVisible = false">
        <div class="w-full bg-dark2 rounded-t-[18px] border-t border-gold/25 pt-2 pb-10">
          <div class="w-10 h-1 rounded-full bg-white/15 mx-auto mb-3.5"></div>
          <div class="text-[1.8rem] text-center py-1">🛵</div>
          <div class="text-[.6rem] text-gray-500 tracking-[.2em] text-center pb-3.5 border-b border-white/[.06] uppercase">Datos del envío</div>
          <input v-model="delNombre" placeholder="Nombre del cliente" autocomplete="off"
            class="block w-[calc(100%-28px)] mx-3.5 mt-2.5 bg-white/[.06] border border-gold/[.18] text-white text-[.9rem] px-3 py-2.5 rounded-[10px] focus:outline-none focus:border-gold/50" />
          <input v-model="delTel" placeholder="Teléfono" type="tel" autocomplete="off"
            class="block w-[calc(100%-28px)] mx-3.5 mt-2.5 bg-white/[.06] border border-gold/[.18] text-white text-[.9rem] px-3 py-2.5 rounded-[10px] focus:outline-none focus:border-gold/50" />
          <input v-model="delDir" placeholder="Dirección (calle y número)" autocomplete="off"
            class="block w-[calc(100%-28px)] mx-3.5 mt-2.5 bg-white/[.06] border border-gold/[.18] text-white text-[.9rem] px-3 py-2.5 rounded-[10px] focus:outline-none focus:border-gold/50" />
          <input v-model="delRef" placeholder="Referencia: piso, timbre, depto..." autocomplete="off"
            class="block w-[calc(100%-28px)] mx-3.5 mt-2.5 bg-white/[.06] border border-gold/[.18] text-white text-[.9rem] px-3 py-2.5 rounded-[10px] focus:outline-none focus:border-gold/50" />
          <div class="text-[.55rem] text-gray-500 tracking-[.14em] uppercase px-3.5 mt-3.5 mb-1.5">Método de pago (opcional)</div>
          <div class="grid grid-cols-3 gap-1.5 px-3.5">
            <button v-for="m in METODOS" :key="m.id" @click="delMetodo = delMetodo === m.id ? '' : m.id"
              :class="[
                'border rounded-xl py-2.5 px-1.5 text-center flex flex-col items-center gap-0.5 transition-colors cursor-pointer',
                delMetodo === m.id ? 'border-gold bg-gold/[.12]' : 'border-gold/15 bg-white/[.04]',
              ]">
              <div class="text-[1.1rem] leading-none">{{ m.icon }}</div>
              <div :class="['text-[.52rem] font-bold tracking-[.02em] text-center', delMetodo === m.id ? 'text-gold' : 'text-gray-400']">{{ m.label }}</div>
            </button>
          </div>
          <button @click="confirmDelivery"
            class="block w-[calc(100%-28px)] mx-3.5 mt-4 py-3.5 bg-gold text-dark font-bold text-[.9rem] rounded-[10px] tracking-[.04em] cursor-pointer border-none">Abrir pedido →</button>
          <button @click="delFormVisible = false"
            class="block w-[calc(100%-28px)] mx-3.5 mt-2 py-2.5 text-white/30 border border-white/10 rounded-lg text-[.8rem] bg-transparent tracking-[.04em] cursor-pointer">Cancelar</button>
        </div>
      </div>
    </Transition>

    <!-- ══════════════════════════════════════ LLEVAR FORM ══ -->
    <Transition name="sheet">
      <div v-if="llevarFormVisible" class="fixed inset-0 bg-black/72 z-[80] flex items-end" @click.self="llevarFormVisible = false">
        <div class="w-full bg-dark2 rounded-t-[18px] border-t border-gold/25 pt-2 pb-10">
          <div class="w-10 h-1 rounded-full bg-white/15 mx-auto mb-3.5"></div>
          <div class="text-[1.8rem] text-center py-1">🛍️</div>
          <div class="text-[.6rem] text-gray-500 tracking-[.2em] text-center pb-3.5 border-b border-white/[.06] uppercase">Datos del pedido para llevar</div>
          <input v-model="llevarNombre" placeholder="Nombre y apellido *" autocomplete="off"
            class="block w-[calc(100%-28px)] mx-3.5 mt-2.5 bg-white/[.06] border border-gold/[.18] text-white text-[.9rem] px-3 py-2.5 rounded-[10px] focus:outline-none focus:border-gold/50" />
          <input v-model="llevarTel" placeholder="Teléfono" type="tel" autocomplete="off"
            class="block w-[calc(100%-28px)] mx-3.5 mt-2.5 bg-white/[.06] border border-gold/[.18] text-white text-[.9rem] px-3 py-2.5 rounded-[10px] focus:outline-none focus:border-gold/50" />
          <button @click="confirmLlevar"
            class="block w-[calc(100%-28px)] mx-3.5 mt-4 py-3.5 bg-gold text-dark font-bold text-[.9rem] rounded-[10px] tracking-[.04em] cursor-pointer border-none">Abrir pedido →</button>
          <button @click="llevarFormVisible = false"
            class="block w-[calc(100%-28px)] mx-3.5 mt-2 py-2.5 text-white/30 border border-white/10 rounded-lg text-[.8rem] bg-transparent tracking-[.04em] cursor-pointer">Cancelar</button>
        </div>
      </div>
    </Transition>

    <!-- ═══════════════════════════════ MESA CONFIRM MODAL ══ -->
    <Transition name="fade">
      <div v-if="confirmMesaKey" class="fixed inset-0 bg-black/78 z-[90] flex items-center justify-center p-6" @click.self="confirmMesaKey = null">
        <div class="bg-dark2 border border-gold/30 rounded-[18px] p-7 w-full max-w-[300px] text-center">
          <div class="font-display text-[1.25rem] font-black text-gold mb-1.5">{{ mesaKeyLabel(confirmMesaKey) }}</div>
          <div class="text-[.75rem] text-gray-500 mb-5 tracking-[.03em]">¿Querés abrir esta mesa?</div>
          <div class="flex gap-2">
            <button @click="confirmMesaKey = null"
              class="px-4 py-3 text-gray-500 border border-gold/[.18] rounded-[10px] text-[.85rem] bg-transparent cursor-pointer">Cancelar</button>
            <button @click="confirmOpenMesa"
              class="flex-1 py-3 bg-gold/[.15] text-gold border-[1.5px] border-gold/45 rounded-[10px] font-bold text-[.9rem] tracking-[.04em] cursor-pointer">Abrir mesa</button>
          </div>
        </div>
      </div>
    </Transition>

    <!-- ══════════════════════════════════════════ TOAST ══ -->
    <Transition name="toastfade">
      <div v-if="toastMsg"
        class="fixed bottom-[130px] left-1/2 -translate-x-1/2 bg-[rgba(40,40,40,.96)] text-white
               px-[18px] py-2 rounded-[20px] text-[.8rem] tracking-[.04em] pointer-events-none
               z-[999] whitespace-nowrap border border-gold/[.18]">
        {{ toastMsg }}
      </div>
    </Transition>
  </div>
</template>

<style scoped>
.slide-down-enter-active, .slide-down-leave-active { transition: transform .25s ease; }
.slide-down-enter-from, .slide-down-leave-to { transform: translateY(-100%); }
.sheet-enter-active, .sheet-leave-active { transition: opacity .2s ease; }
.sheet-enter-from, .sheet-leave-to { opacity: 0; }
.fade-enter-active, .fade-leave-active { transition: opacity .2s ease; }
.fade-enter-from, .fade-leave-to { opacity: 0; }
.toastfade-enter-active, .toastfade-leave-active { transition: opacity .3s ease; }
.toastfade-enter-from, .toastfade-leave-to { opacity: 0; }
</style>
