<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/services/supabase'
import { useAuthStore } from '@/stores/auth.store'
import { clockBsAs, todayBsAs, dayStartUTC } from '@/utils/timezone'
import type { Pedido } from '@/types/domain'

const router = useRouter()
const auth   = useAuthStore()

// ── State ─────────────────────────────────────────────
const orders     = ref<Pedido[]>([])
const clock      = ref('--:--:--')
const rtStatus   = ref<'connecting' | 'connected' | 'error'>('connecting')
const flashMsg   = ref('')
const flashVisible = ref(false)
const loadError  = ref(false)

let listoDesde = dayStartUTC(todayBsAs())

let clockInterval: ReturnType<typeof setInterval> | null = null
let timeagoInterval: ReturnType<typeof setInterval> | null = null
let flashTimer: ReturnType<typeof setTimeout> | null = null
let kitchenChannel: ReturnType<typeof supabase.channel> | null = null
let cierreChannel: ReturnType<typeof supabase.channel> | null = null

// ── Computed ──────────────────────────────────────────
const pendingOrders = computed(() => orders.value.filter(o => o.estado === 'pendiente'))
const doneOrders    = computed(() => orders.value.filter(o => o.estado === 'listo'))

// ── Helpers ───────────────────────────────────────────
interface SesionRef { mesa?: string; tipo?: string; cliente_nombre?: string; cliente_direccion?: string }

function mesaLabel(sesion: SesionRef | string | undefined): string {
  if (!sesion) return 'DESCONOCIDO'
  const s: SesionRef = typeof sesion === 'string' ? { mesa: sesion } : sesion
  const mesa = s.mesa ?? ''
  if (mesa === 'llevar') return 'PARA LLEVAR'
  if (mesa.startsWith('llevar_')) {
    return s.cliente_nombre ? `LLEVAR — ${s.cliente_nombre}` : 'PARA LLEVAR'
  }
  if (mesa.startsWith('envio_')) {
    if (s.cliente_nombre && s.cliente_direccion) return `ENVÍO — ${s.cliente_nombre} · ${s.cliente_direccion}`
    if (s.cliente_nombre) return `ENVÍO — ${s.cliente_nombre}`
    return 'ENVÍO'
  }
  return `MESA ${mesa.replace('mesa_', '')}`
}

function formatTime(iso: string): string {
  return new Date(iso).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })
}

function timeAgo(iso: string): string {
  const s = Math.floor((Date.now() - new Date(iso).getTime()) / 1000)
  if (s < 60)   return `${s}s`
  if (s < 3600) return `${Math.floor(s / 60)} min`
  return `${Math.floor(s / 3600)}h ${Math.floor((s % 3600) / 60)}min`
}

function isLate(iso: string): boolean {
  return (Date.now() - new Date(iso).getTime()) > 15 * 60 * 1000
}

function durMin(order: Pedido): number | null {
  if (!order.listo_at) return null
  return Math.round((new Date(order.listo_at).getTime() - new Date(order.created_at).getTime()) / 60000)
}

// ── Ticker for time-ago labels ────────────────────────
const tick = ref(0)
function startTickers() {
  clockInterval   = setInterval(() => { clock.value = clockBsAs() }, 1000)
  timeagoInterval = setInterval(() => { tick.value++ }, 30000)
  clock.value = clockBsAs()
}

// ── Sound ─────────────────────────────────────────────
function playBeep(freqs: number[]) {
  try {
    const Ctx = window.AudioContext || (window as unknown as Record<string, unknown>)['webkitAudioContext'] as typeof AudioContext
    const ctx = new Ctx()
    freqs.forEach((freq, i) => {
      const osc = ctx.createOscillator()
      const gain = ctx.createGain()
      osc.connect(gain); gain.connect(ctx.destination)
      osc.frequency.value = freq
      const t = ctx.currentTime + i * 0.18
      gain.gain.setValueAtTime(0.25, t)
      gain.gain.exponentialRampToValueAtTime(0.001, t + 0.25)
      osc.start(t); osc.stop(t + 0.25)
    })
  } catch { /* silenced */ }
}

// ── Flash notification ────────────────────────────────
function showFlash(msg: string) {
  flashMsg.value = msg
  flashVisible.value = true
  if (flashTimer) clearTimeout(flashTimer)
  flashTimer = setTimeout(() => { flashVisible.value = false }, 3000)
}

// ── New order animation IDs ───────────────────────────
const newOrderIds = ref<Set<string>>(new Set())
function markNew(id: string) {
  newOrderIds.value = new Set([...newOrderIds.value, id])
  setTimeout(() => {
    newOrderIds.value = new Set([...newOrderIds.value].filter(x => x !== id))
  }, 3000)
}

// ── Load orders ───────────────────────────────────────
async function loadOrders() {
  loadError.value = false
  try {
    const [{ data: pending }, { data: done }] = await Promise.all([
      supabase
        .from('pedidos')
        .select('*, sesiones(mesa,tipo,cliente_nombre,cliente_direccion), pedido_items(*)')
        .eq('estado', 'pendiente')
        .order('created_at', { ascending: true }),
      supabase
        .from('pedidos')
        .select('*, sesiones(mesa,tipo,cliente_nombre,cliente_direccion), pedido_items(*)')
        .eq('estado', 'listo')
        .gte('listo_at', listoDesde)
        .order('listo_at', { ascending: false })
        .limit(15),
    ])
    orders.value = [...(pending as Pedido[] ?? []), ...(done as Pedido[] ?? [])]
  } catch {
    loadError.value = true
  }
}

// ── Mark as ready ─────────────────────────────────────
const markingReady = ref<Set<string>>(new Set())

async function markListo(id: string) {
  if (markingReady.value.has(id)) return
  markingReady.value = new Set([...markingReady.value, id])
  const listo_at = new Date().toISOString()
  try {
    await supabase.from('pedidos').update({ estado: 'listo', listo_at }).eq('id', id)
    const order = orders.value.find(o => o.id === id)
    if (order) { order.estado = 'listo'; order.listo_at = listo_at }
  } catch { /* ignore */ }
  markingReady.value = new Set([...markingReady.value].filter(x => x !== id))
}

// ── Check today's cierre ──────────────────────────────
async function checkTodayCierre() {
  const today = todayBsAs()
  const { data } = await supabase
    .from('cierres')
    .select('created_at')
    .eq('fecha', today)
    .order('created_at', { ascending: false })
    .limit(1)
    .maybeSingle()
  if (data?.created_at) listoDesde = data.created_at
}

// ── Realtime ──────────────────────────────────────────
function setupRealtime() {
  cierreChannel = supabase
    .channel('kitchen-cierre')
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'cierres' }, payload => {
      if (payload.new?.created_at) listoDesde = payload.new.created_at
      orders.value = orders.value.filter(o => o.estado === 'pendiente')
    })
    .subscribe()

  kitchenChannel = supabase
    .channel('kitchen-orders')
    .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'pedidos' }, async payload => {
      const { data } = await supabase
        .from('pedidos')
        .select('*, sesiones(mesa,tipo,cliente_nombre,cliente_direccion), pedido_items(*)')
        .eq('id', payload.new.id)
        .single()
      if (data) {
        orders.value.unshift(data as Pedido)
        const tipo = data.tipo
        const sesRef = (data as Pedido).sesiones
        if (tipo === 'cambio') {
          playBeep([1000, 800, 600])
          showFlash(`⚠️ CAMBIO — ${mesaLabel(sesRef)}`)
        } else if (tipo === 'cancelacion') {
          playBeep([1000, 800, 600])
          showFlash(`🚫 CANCELAR — ${mesaLabel(sesRef)}`)
        } else {
          playBeep([880, 1100])
          showFlash(`🔔 NUEVO PEDIDO — ${mesaLabel(sesRef)}`)
        }
        markNew(data.id)
      }
    })
    .subscribe(status => {
      if (status === 'SUBSCRIBED') rtStatus.value = 'connected'
      else if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
        rtStatus.value = 'error'
        setInterval(loadOrders, 30000)
      } else rtStatus.value = 'connecting'
    })
}

// ── Wake lock ─────────────────────────────────────────
async function keepScreenOn() {
  try {
    if ('wakeLock' in navigator) await (navigator as Navigator & { wakeLock: { request: (t: string) => Promise<void> } }).wakeLock.request('screen')
  } catch { /* not supported */ }
}

// ── Lifecycle ─────────────────────────────────────────
onMounted(async () => {
  keepScreenOn()
  await checkTodayCierre()
  await loadOrders()
  setupRealtime()
  startTickers()
})

onUnmounted(() => {
  kitchenChannel?.unsubscribe()
  cierreChannel?.unsubscribe()
  if (clockInterval) clearInterval(clockInterval)
  if (timeagoInterval) clearInterval(timeagoInterval)
  if (flashTimer) clearTimeout(flashTimer)
})

async function doLogout() {
  await auth.logout()
  router.replace({ name: 'login' })
}
</script>

<template>
  <div class="fixed inset-0 flex flex-col bg-[#0a0a0a] text-white overflow-hidden" style="font-family:'Lato',sans-serif">

    <!-- Flash notification -->
    <Transition name="flash">
      <div v-if="flashVisible"
        class="fixed top-0 left-0 right-0 z-50 bg-gold text-black font-black text-[.95rem] tracking-[.06em] text-center py-3">
        {{ flashMsg }}
      </div>
    </Transition>

    <!-- Header -->
    <header class="bg-[#161616] border-b-2 border-gold/20 px-[18px] py-3.5 flex items-center gap-3 sticky top-0 z-20">
      <span class="font-display text-[1.15rem] font-black text-gold tracking-[.06em]">Lescano's</span>
      <span class="text-[#666] text-[.9rem]">·</span>
      <span class="text-[.8rem] font-bold text-[#bbb] tracking-[.14em] uppercase">Cocina</span>
      <div class="ml-auto flex items-center gap-2.5">
        <span class="text-[.82rem] font-bold text-gold tracking-[.06em]">{{ clock }}</span>
        <span :class="[
          'text-[.75rem] font-black px-3 py-1 rounded-[20px] tracking-[.04em] min-w-[28px] text-center',
          pendingOrders.length > 0 ? 'bg-gold text-black' : 'bg-white/10 text-[#666]'
        ]">{{ pendingOrders.length }}</span>
        <button @click="loadOrders"
          class="border border-gold/20 text-gold text-[.72rem] px-3 py-1.5 rounded-md bg-transparent cursor-pointer tracking-[.06em]">
          ↻ Actualizar
        </button>
        <button v-if="auth.can('dueno')" @click="router.replace({ name: 'mesas' })"
          class="border border-gold/20 text-gold/60 text-[.62rem] px-2.5 py-1 rounded bg-transparent cursor-pointer tracking-[.08em]">
          ← Mesas
        </button>
        <button @click="doLogout"
          class="border border-gold/30 text-gold/70 text-[.62rem] px-2.5 py-1 rounded bg-transparent cursor-pointer tracking-[.08em]">
          Salir
        </button>
      </div>
    </header>

    <!-- Realtime status bar -->
    <div class="flex items-center gap-1.5 px-[18px] py-1.5 bg-black/40 border-b border-white/[.04] text-[.6rem] text-[#666] tracking-[.08em]">
      <span :class="[
        'w-[7px] h-[7px] rounded-full flex-shrink-0 transition-colors',
        rtStatus === 'connected' ? 'bg-green-500' :
        rtStatus === 'connecting' ? 'bg-gold animate-pulse' : 'bg-[#666]'
      ]"></span>
      <span v-if="rtStatus === 'connected'">En tiempo real</span>
      <span v-else-if="rtStatus === 'connecting'">Conectando en tiempo real...</span>
      <span v-else>Sin tiempo real — actualizando cada 30s</span>
    </div>

    <!-- Main content -->
    <div class="flex-1 overflow-y-auto px-3.5 py-4 pb-10">

      <!-- Error state -->
      <div v-if="loadError" class="text-center py-12 text-[#666]">
        <div class="text-5xl mb-3 opacity-30">⚠️</div>
        <div class="text-[.9rem] tracking-[.04em]">Error al cargar. Revisá la conexión.</div>
      </div>

      <template v-else>
        <!-- Section label -->
        <div class="text-[.58rem] text-[#666] tracking-[.22em] uppercase mb-2.5 flex items-center gap-2">
          Pedidos pendientes
          <div class="flex-1 h-px bg-white/[.06]"></div>
        </div>

        <!-- Pending grid -->
        <div class="grid gap-3 mb-7" style="grid-template-columns:repeat(auto-fill,minmax(290px,1fr))">
          <!-- Empty state -->
          <div v-if="pendingOrders.length === 0"
            class="col-span-full text-center py-12 text-[#666]">
            <div class="text-5xl mb-3 opacity-30">✓</div>
            <div class="text-[.9rem] tracking-[.04em]">Sin pedidos pendientes</div>
          </div>

          <!-- Order cards -->
          <div
            v-for="order in pendingOrders" :key="order.id"
            :class="[
              'rounded-[14px] overflow-hidden transition-all border-2',
              order.tipo === 'cambio'      ? 'border-[#E89500]/70 bg-[#E89500]/[.04]' :
              order.tipo === 'cancelacion' ? 'border-red-500/70 bg-red-500/[.04]' :
                                             'border-gold/35 bg-[#161616]',
              newOrderIds.has(order.id) ? 'ring-4 ring-gold/30' : '',
            ]"
          >
            <!-- Card header -->
            <div :class="[
              'px-3.5 py-3 border-b flex items-baseline gap-2',
              order.tipo === 'cambio'      ? 'bg-[#E89500]/10 border-[#E89500]/25' :
              order.tipo === 'cancelacion' ? 'bg-red-500/10 border-red-500/25' :
                                             'bg-gold/[.08] border-gold/20'
            ]">
              <span class="font-display text-[1.3rem] font-black text-gold flex-1 tracking-[.04em]">
                {{ mesaLabel(order.sesiones) }}
              </span>
              <span v-if="order.tipo === 'cambio'"
                class="text-[.62rem] font-black text-[#E89500] tracking-[.12em] bg-[#E89500]/15 px-2 py-0.5 rounded-md">
                ⚠️ CAMBIO
              </span>
              <span v-else-if="order.tipo === 'cancelacion'"
                class="text-[.62rem] font-black text-red-400 tracking-[.12em] bg-red-400/15 px-2 py-0.5 rounded-md">
                🚫 CANCELAR
              </span>
              <!-- time-ago, re-renders every tick -->
              <span :key="tick" :class="['text-[.68rem] tracking-[.04em] whitespace-nowrap', isLate(order.created_at) ? 'text-red-400' : 'text-[#666]']">
                {{ timeAgo(order.created_at) }}
              </span>
            </div>

            <!-- Items -->
            <div class="px-3.5 pt-3 pb-1.5">
              <div v-for="item in (order.pedido_items || [])" :key="item.id"
                class="flex gap-2.5 py-1.5 border-b border-white/[.04] last:border-0">
                <span class="font-display text-[1.05rem] font-black text-gold min-w-[28px] flex-shrink-0 leading-tight">{{ item.qty }}×</span>
                <div class="flex-1">
                  <div class="text-[.95rem] font-bold text-white leading-tight">{{ item.nombre }}</div>
                  <div v-if="item.seccion && item.seccion !== 'CANCELACION' && item.seccion !== 'CAMBIO'"
                    class="text-[.62rem] text-gold/45 tracking-[.08em] uppercase mt-0.5">{{ item.seccion }}</div>
                  <div v-if="item.nota" class="text-[.72rem] text-[#aaa] italic mt-0.5 leading-snug">📝 {{ item.nota }}</div>
                </div>
              </div>
            </div>

            <!-- Listo button -->
            <button
              @click="markListo(order.id)"
              :disabled="markingReady.has(order.id)"
              class="w-[calc(100%-28px)] mx-3.5 mb-3.5 mt-2.5 py-3.5 bg-[#2d7a2d] text-white border-none rounded-[10px]
                     font-black text-[.95rem] tracking-[.06em] cursor-pointer disabled:opacity-50 disabled:cursor-default
                     active:bg-[#1e5c1e] active:scale-[.98] transition-all"
            >
              {{ markingReady.has(order.id) ? 'Guardando...' : '✓  Listo' }}
            </button>
          </div>
        </div>

        <!-- Done section -->
        <div v-if="doneOrders.length > 0">
          <div class="text-[.58rem] text-[#666] tracking-[.22em] uppercase mb-2.5 flex items-center gap-2">
            Listos hoy
            <div class="flex-1 h-px bg-white/[.06]"></div>
          </div>
          <div class="flex flex-col gap-1.5">
            <div v-for="order in doneOrders" :key="order.id"
              class="bg-[#1e1e1e] border border-white/[.06] rounded-[10px] px-3.5 py-2.5 flex items-center gap-2.5 flex-wrap">
              <span class="text-green-400 text-[.9rem] flex-shrink-0">✓</span>
              <span class="text-[.82rem] font-bold text-[#aaa] flex-shrink-0">{{ mesaLabel(order.sesiones) }}</span>
              <span class="text-[.75rem] text-[#666] flex-1 leading-snug">
                <template v-for="(item, i) in (order.pedido_items || [])" :key="item.id">
                  <span v-if="i > 0"> · </span>
                  {{ item.qty }}× {{ item.nombre }}<span v-if="item.nota" class="italic opacity-70"> ({{ item.nota }})</span>
                </template>
              </span>
              <span class="text-[.65rem] text-[#666] whitespace-nowrap ml-auto">
                {{ formatTime(order.created_at) }}{{ order.listo_at ? ` → ${formatTime(order.listo_at)}` : '' }}
              </span>
              <span v-if="durMin(order) !== null"
                class="text-[.58rem] bg-green-500/15 text-green-400 px-1.5 py-0.5 rounded-lg whitespace-nowrap">
                {{ durMin(order) }} min
              </span>
            </div>
          </div>
        </div>
      </template>
    </div>
  </div>
</template>

<style scoped>
.flash-enter-active, .flash-leave-active { transition: transform .25s ease; }
.flash-enter-from, .flash-leave-to { transform: translateY(-100%); }
</style>
