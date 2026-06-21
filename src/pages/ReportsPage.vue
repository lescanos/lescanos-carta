<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/services/supabase'
import { useAuthStore } from '@/stores/auth.store'
import { todayBsAs, dayStartUTC, dayEndUTC } from '@/utils/timezone'
import { useInactivityLogout } from '@/composables/useInactivityLogout'

const router = useRouter()
const auth   = useAuthStore()

useInactivityLogout()

// ── Types ─────────────────────────────────────────────
interface SessionRow {
  id: string; mesa: string; estado: string; cubiertos: number | null
  created_at: string; closed_at: string | null; moza_nombre: string | null
  pagos: { metodo: string; monto: number }[] | null
}
interface ItemRow { id: string; sesion_id: string; nombre: string; precio: string; qty: number; seccion: string | null }

// ── Constants ─────────────────────────────────────────
const METODOS = [
  { id: 'efectivo',      label: 'Efectivo',     icon: '💵' },
  { id: 'debito',        label: 'Débito',        icon: '💳' },
  { id: 'credito',       label: 'Crédito',       icon: '🏦' },
  { id: 'transferencia', label: 'Transferencia', icon: '📱' },
  { id: 'mercadopago',   label: 'Mercado Pago',  icon: '🔵' },
  { id: 'pedidosya',     label: 'Pedidos Ya',    icon: '🛵' },
]

// ── State ─────────────────────────────────────────────
const currentDate = ref(todayBsAs())
const loading     = ref(false)
const loadError   = ref(false)
const sessions    = ref<SessionRow[]>([])
const allItems    = ref<ItemRow[]>([])
const cierre      = ref<Record<string, unknown> | null>(null)
const cierreVisible = ref(false)
const cierreNotas   = ref('')
const cierreLoading = ref(false)

// ── Helpers ───────────────────────────────────────────
function parsePrecio(p: string): number {
  return parseInt((p || '').replace(/\D/g, '')) || 0
}

function mesaLabel(mesa: string): string {
  if (mesa.startsWith('llevar')) return 'Para llevar'
  if (mesa.startsWith('envio_')) return 'Envío'
  return `Mesa ${mesa.replace('mesa_', '')}`
}

function formatTime(iso: string): string {
  return new Date(iso).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' })
}

function formatDate(dateStr: string): string {
  const [y, m, d] = dateStr.split('-').map(Number)
  return new Date(y, m - 1, d).toLocaleDateString('es-AR', { weekday: 'long', day: 'numeric', month: 'long' })
}

function navigateDate(delta: number) {
  const [y, m, d] = currentDate.value.split('-').map(Number)
  const next = new Date(y, m - 1, d + delta)
  const str = next.toLocaleDateString('en-CA')
  if (str > todayBsAs()) return
  currentDate.value = str
  loadReport()
}

// ── Computed ──────────────────────────────────────────
const closedSessions = computed(() => sessions.value.filter(s => s.estado === 'cerrada'))
const openSessions   = computed(() => sessions.value.filter(s => s.estado === 'abierta'))

function sessionTotal(s: SessionRow): number {
  return (s.pagos ?? []).reduce((sum, p) => sum + Number(p.monto), 0)
}

const totalVentas = computed(() =>
  closedSessions.value.reduce((sum, s) => sum + sessionTotal(s), 0)
)
const totalCubiertos = computed(() =>
  closedSessions.value.reduce((sum, s) => sum + (s.cubiertos || 1), 0)
)
const ticketPorPersona = computed(() =>
  totalCubiertos.value > 0 ? Math.round(totalVentas.value / totalCubiertos.value) : 0
)

const byMetodo = computed(() => {
  const result: Record<string, { total: number; count: number }> = {}
  METODOS.forEach(m => { result[m.id] = { total: 0, count: 0 } })
  closedSessions.value.forEach(s => {
    (s.pagos ?? []).forEach(pago => {
      if (result[pago.metodo]) {
        result[pago.metodo].total += Number(pago.monto)
        result[pago.metodo].count++
      }
    })
  })
  return result
})

const topProducts = computed(() => {
  const closedIds = new Set(closedSessions.value.map(s => s.id))
  const itemCount: Record<string, number> = {}
  allItems.value.filter(i => closedIds.has(i.sesion_id)).forEach(item => {
    itemCount[item.nombre] = (itemCount[item.nombre] || 0) + item.qty
  })
  return Object.entries(itemCount).sort((a, b) => b[1] - a[1]).slice(0, 8)
})

const cierreYaHecho = computed(() => !!cierre.value)

const cierreData = computed(() => {
  const totals: Record<string, number> = { total: 0, efectivo: 0, debito: 0, credito: 0, transferencia: 0, mercadopago: 0, pedidosya: 0 }
  closedSessions.value.forEach(s => {
    (s.pagos ?? []).forEach(pago => {
      if (pago.metodo in totals) {
        totals[pago.metodo] += Number(pago.monto)
        totals.total += Number(pago.monto)
      }
    })
  })
  return totals
})

// ── Load ──────────────────────────────────────────────
async function loadReport() {
  loading.value = true
  loadError.value = false
  const dayStart = dayStartUTC(currentDate.value)
  const dayEnd   = dayEndUTC(currentDate.value)
  try {
    const [{ data: sess }, { data: closedToday }, { data: cierreResult }] = await Promise.all([
      supabase.from('sesiones').select('*, pagos(*)').gte('created_at', dayStart).lte('created_at', dayEnd).order('created_at', { ascending: true }),
      supabase.from('sesiones').select('*, pagos(*)').gte('closed_at', dayStart).lte('closed_at', dayEnd).lt('created_at', dayStart),
      supabase.from('cierres').select('*').eq('fecha', currentDate.value).limit(1),
    ])
    const merged = [...(sess as SessionRow[] ?? [])]
    ;(closedToday as SessionRow[] ?? []).forEach(s => {
      if (!merged.find(x => x.id === s.id)) merged.push(s)
    })
    sessions.value = merged
    cierre.value = (cierreResult as Record<string, unknown>[] ?? [])[0] ?? null

    const sessIds = merged.map(s => s.id)
    if (sessIds.length > 0) {
      const { data: items } = await supabase.from('pedido_items').select('id,sesion_id,nombre,precio,qty,seccion').in('sesion_id', sessIds)
      allItems.value = (items as ItemRow[]) ?? []
    } else {
      allItems.value = []
    }
  } catch { loadError.value = true }
  loading.value = false
}

function sessionItemCount(sesionId: string): number {
  return allItems.value.filter(i => i.sesion_id === sesionId).reduce((s, i) => s + i.qty, 0)
}

function sessionSubtotal(sesionId: string): number {
  return allItems.value.filter(i => i.sesion_id === sesionId).reduce((s, i) => s + parsePrecio(i.precio) * i.qty, 0)
}

// ── CSV export ────────────────────────────────────────
function exportCSV() {
  const closed = closedSessions.value
  const closedIds = new Set(closed.map(s => s.id))
  let csv = '﻿'
  csv += 'Fecha,Mesa,Apertura,Cierre,Método de pago,Total\n'
  closed.forEach(s => {
    const metodos = (s.pagos ?? []).map(p => METODOS.find(m => m.id === p.metodo)?.label ?? p.metodo).join(' + ') || ''
    csv += `"${currentDate.value}","${mesaLabel(s.mesa)}","${new Date(s.created_at).toLocaleString('es-AR')}","${s.closed_at ? new Date(s.closed_at).toLocaleString('es-AR') : ''}","${metodos}","${sessionTotal(s)}"\n`
  })
  csv += '\nFecha,Producto,Sección,Precio,Cantidad\n'
  allItems.value.filter(i => closedIds.has(i.sesion_id)).forEach(i => {
    csv += `"${currentDate.value}","${i.nombre}","${i.seccion ?? ''}","${i.precio}","${i.qty}"\n`
  })
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
  const url = URL.createObjectURL(blob)
  const a = document.createElement('a')
  a.href = url; a.download = `lescanos-${currentDate.value}.csv`; a.click()
  URL.revokeObjectURL(url)
}

// ── Cierre de caja ────────────────────────────────────
const cierreBlockers = ref<string[]>([])

async function openCierreModal() {
  cierreNotas.value = ''
  cierreBlockers.value = []

  // Verificar precondiciones: no mesas abiertas, no pedidos pendientes
  const blockers: string[] = []
  const { data: openSes } = await supabase.from('sesiones').select('id', { count: 'exact' }).eq('estado', 'abierta')
  if ((openSes?.length ?? 0) > 0) blockers.push(`Hay ${openSes!.length} mesa(s) aún abiertas. Cerrá todas las mesas antes de hacer el cierre.`)

  const { data: pendPed } = await supabase.from('pedidos').select('id', { count: 'exact' }).eq('estado', 'pendiente')
  if ((pendPed?.length ?? 0) > 0) blockers.push(`Hay ${pendPed!.length} pedido(s) pendientes en cocina. Esperá que estén listos.`)

  cierreBlockers.value = blockers
  cierreVisible.value = true
}

async function confirmCierre() {
  if (cierreBlockers.value.length > 0) return
  cierreLoading.value = true
  const d = cierreData.value
  try {
    const { error } = await supabase.from('cierres').insert({
      fecha: currentDate.value,
      total: d.total, efectivo: d.efectivo, debito: d.debito, credito: d.credito,
      transferencia: d.transferencia, mercadopago: d.mercadopago, pedidosya: d.pedidosya,
      notas: cierreNotas.value.trim() || null,
    })
    if (error) throw error
    cierreVisible.value = false
    await loadReport()
  } catch (e: unknown) {
    const msg = (e as { message?: string })?.message ?? ''
    if (msg.includes('unique') || msg.includes('duplicate')) {
      alert('Ya existe un cierre para este día.')
    } else {
      alert('Error al guardar el cierre. Intentá de nuevo.')
    }
  }
  cierreLoading.value = false
}

// ── Lifecycle ─────────────────────────────────────────
onMounted(loadReport)

async function doLogout() {
  await auth.logout()
  router.replace({ name: 'login' })
}
</script>

<template>
  <div class="fixed inset-0 flex flex-col bg-dark overflow-hidden">

    <!-- Header -->
    <header class="bg-dark2 border-b border-gold/[.18] px-4 py-3.5 flex items-center gap-2 flex-shrink-0">
      <button @click="router.replace({ name: 'mesas' })" class="text-gold text-2xl leading-none px-1 pr-2 bg-transparent border-none cursor-pointer">‹</button>
      <span class="font-display text-[1rem] font-black text-gold tracking-[.06em]">Lescano's</span>
      <span class="text-[.58rem] text-gray-500 tracking-[.14em] ml-0.5">— Reportes</span>
      <button @click="doLogout"
        class="ml-auto border border-gold/30 text-gold/70 text-[.6rem] px-2.5 py-1 rounded bg-transparent cursor-pointer tracking-[.08em]">
        Salir
      </button>
    </header>

    <!-- Date bar -->
    <div class="flex items-center gap-2.5 px-4 py-2.5 border-b border-gold/[.18] bg-dark2">
      <span class="text-[.62rem] text-gray-500 tracking-[.1em] uppercase">Fecha</span>
      <button @click="navigateDate(-1)"
        class="w-[30px] h-[30px] border border-gold/[.18] text-gold text-lg rounded-md flex items-center justify-center bg-transparent cursor-pointer flex-shrink-0">‹</button>
      <input v-model="currentDate" type="date" :max="todayBsAs()" @change="loadReport"
        class="bg-white/[.06] border border-gold/[.18] text-white text-[.82rem] px-2.5 py-1.5 rounded-md" />
      <button @click="navigateDate(1)"
        class="w-[30px] h-[30px] border border-gold/[.18] text-gold text-lg rounded-md flex items-center justify-center bg-transparent cursor-pointer flex-shrink-0">›</button>
      <button @click="loadReport"
        class="ml-auto border border-gold/[.18] text-gold text-[.72rem] px-2.5 py-1.5 rounded-md bg-transparent cursor-pointer tracking-[.06em]">
        ↻ Actualizar
      </button>
    </div>

    <div class="flex-1 overflow-y-auto px-4 py-4 pb-10">
      <div v-if="loading" class="text-center py-10 text-gray-500 text-[.85rem]">Cargando...</div>
      <div v-else-if="loadError" class="text-center py-10 text-gray-500 text-[.85rem]">Error al cargar datos. Verificá la conexión.</div>

      <template v-else>
        <!-- Date heading -->
        <div class="text-[.58rem] text-gray-500 tracking-[.2em] uppercase mb-2.5">
          {{ formatDate(currentDate) }}
          <span v-if="currentDate === todayBsAs()"
            class="inline-block bg-gold/12 border border-gold/25 text-gold text-[.62rem] px-2 py-0.5 rounded-[10px] ml-2 tracking-[.06em] align-middle">HOY</span>
        </div>

        <!-- Stat cards -->
        <div class="grid grid-cols-3 gap-2 mb-1">
          <div v-for="stat in [
            { val: totalVentas > 0 ? `$${Math.round(totalVentas/1000)}k` : '—', lbl: 'Total ventas' },
            { val: closedSessions.length, lbl: 'Mesas cerradas' },
            { val: ticketPorPersona > 0 ? `$${Math.round(ticketPorPersona/1000)}k` : '—', lbl: 'Por persona' },
          ]" :key="stat.lbl"
            class="bg-dark2 border border-gold/[.18] rounded-xl px-2.5 py-3.5 text-center">
            <div class="font-display text-[1.25rem] font-black text-gold leading-tight break-all">{{ stat.val }}</div>
            <div class="text-[.52rem] text-gray-500 tracking-[.1em] uppercase mt-1">{{ stat.lbl }}</div>
          </div>
        </div>

        <!-- Payment breakdown -->
        <div class="text-[.58rem] text-gray-500 tracking-[.2em] uppercase mt-5 mb-2.5">Por método de pago</div>
        <div class="flex flex-col gap-1.5">
          <div v-for="m in METODOS" :key="m.id"
            :class="['bg-dark2 border border-gold/[.18] rounded-[10px] px-3.5 py-2.5 flex items-center gap-2.5', byMetodo[m.id]?.count === 0 ? 'opacity-35' : '']">
            <span class="text-[1.1rem] flex-shrink-0">{{ m.icon }}</span>
            <span class="flex-1 text-[.82rem] font-bold text-[#ddd]">{{ m.label }}</span>
            <span class="font-display text-[.88rem] text-gold font-bold">{{ byMetodo[m.id]?.total > 0 ? `$${byMetodo[m.id].total.toLocaleString('es-AR')}` : '—' }}</span>
            <span v-if="byMetodo[m.id]?.count > 0" class="text-[.62rem] text-gray-500 ml-1.5">{{ byMetodo[m.id].count }} mesa{{ byMetodo[m.id].count !== 1 ? 's' : '' }}</span>
          </div>
        </div>

        <!-- Open sessions -->
        <template v-if="openSessions.length > 0">
          <div class="text-[.58rem] text-gray-500 tracking-[.2em] uppercase mt-5 mb-2.5">Mesas abiertas ahora ({{ openSessions.length }})</div>
          <div class="flex flex-col gap-1.5">
            <div v-for="s in openSessions" :key="s.id" class="bg-dark2 border border-gold/50 rounded-[10px] px-3.5 py-3">
              <div class="flex items-center gap-2">
                <span class="font-display text-[.95rem] font-black text-gold min-w-[52px]">{{ mesaLabel(s.mesa) }}</span>
                <span class="text-[.52rem] bg-gold/20 text-gold px-1.5 py-0.5 rounded-[10px] font-bold tracking-[.06em]">ABIERTA</span>
                <span class="text-[.62rem] text-gray-500 ml-auto">desde {{ formatTime(s.created_at) }}</span>
              </div>
              <div class="flex items-center gap-2 mt-1.5">
                <span class="text-[.6rem] text-gray-500">{{ sessionItemCount(s.id) }} items enviados</span>
                <span v-if="sessionSubtotal(s.id) > 0" class="font-display text-[.9rem] text-gold font-bold ml-auto">~${{ sessionSubtotal(s.id).toLocaleString('es-AR') }}</span>
              </div>
            </div>
          </div>
        </template>

        <!-- Closed sessions -->
        <div class="text-[.58rem] text-gray-500 tracking-[.2em] uppercase mt-5 mb-2.5">Mesas cerradas ({{ closedSessions.length }})</div>
        <div v-if="closedSessions.length === 0"
          class="text-center py-5 text-gray-500 text-[.82rem] border border-dashed border-white/10 rounded-[10px]">
          No hay mesas cerradas en esta fecha.
        </div>
        <div v-else class="flex flex-col gap-1.5">
          <div v-for="s in [...closedSessions].reverse()" :key="s.id" class="bg-dark2 border border-gold/[.18] rounded-[10px] px-3.5 py-3">
            <div class="flex items-center gap-2">
              <span class="font-display text-[.95rem] font-black text-gold min-w-[52px]">{{ mesaLabel(s.mesa) }}</span>
              <span class="text-[.52rem] bg-white/[.06] text-gray-500 px-1.5 py-0.5 rounded-[10px] font-bold tracking-[.06em]">CERRADA</span>
              <span class="text-[.62rem] text-gray-500 ml-auto">{{ formatTime(s.created_at) }} → {{ s.closed_at ? formatTime(s.closed_at) : '—' }}</span>
            </div>
            <div class="flex items-center gap-2 mt-1.5 flex-wrap">
              <span class="text-[.68rem] text-[#aaa]">
                {{ (s.pagos?.length ?? 0) > 0
                  ? s.pagos!.map(p => `${METODOS.find(m => m.id === p.metodo)?.icon ?? ''} ${METODOS.find(m => m.id === p.metodo)?.label ?? p.metodo}`).join(' · ')
                  : 'Sin pago registrado' }}
              </span>
              <span v-if="s.moza_nombre" class="text-[.62rem] text-gold/70">{{ s.moza_nombre }}</span>
              <span class="text-[.6rem] text-gray-500">{{ sessionItemCount(s.id) }} items · {{ s.cubiertos || 1 }} cub.</span>
              <span v-if="sessionTotal(s) > 0"
                class="font-display text-[.9rem] text-gold font-bold ml-auto">
                ${{ sessionTotal(s).toLocaleString('es-AR') }}
              </span>
            </div>
          </div>
        </div>

        <!-- Top products -->
        <template v-if="topProducts.length > 0">
          <div class="text-[.58rem] text-gray-500 tracking-[.2em] uppercase mt-5 mb-2.5">Productos más pedidos</div>
          <div class="flex flex-col gap-1">
            <div v-for="([nombre, qty], i) in topProducts" :key="nombre"
              class="bg-dark2 border border-gold/[.18] rounded-lg px-3 py-2.5 flex items-center gap-2.5">
              <span :class="['font-display text-[.85rem] font-black min-w-[20px] text-center', i === 0 ? 'text-gold' : 'text-gold/40']">{{ i + 1 }}</span>
              <span class="flex-1 text-[.82rem] text-[#ddd]">{{ nombre }}</span>
              <span class="bg-gold/15 text-gold text-[.72rem] font-bold px-2 py-0.5 rounded-[10px]">{{ qty }}×</span>
            </div>
          </div>
        </template>

        <!-- Actions -->
        <div class="flex flex-col gap-2 mt-6">
          <button v-if="closedSessions.length > 0" @click="exportCSV"
            class="w-full py-3.5 text-gold border-[1.5px] border-gold text-[.88rem] font-bold rounded-[10px] tracking-[.04em] bg-transparent cursor-pointer">
            📊 Exportar CSV del día
          </button>
          <button @click="openCierreModal" :disabled="cierreYaHecho"
            :class="[
              'w-full py-3.5 text-[.88rem] font-bold rounded-[10px] tracking-[.04em] border-[1.5px] bg-[#1a3a1a] text-green-400 border-green-400/35',
              cierreYaHecho ? 'opacity-60 cursor-default' : 'cursor-pointer',
            ]">
            {{ cierreYaHecho ? '✓ Cierre de caja registrado' : '🔒 Realizar cierre de caja' }}
          </button>
        </div>
      </template>
    </div>

    <!-- Cierre modal -->
    <Transition name="fade">
      <div v-if="cierreVisible" class="fixed inset-0 bg-black/80 z-50 flex items-center justify-center p-5" @click.self="cierreVisible = false">
        <div :class="['bg-[#1a1a1a] rounded-[16px] p-6 w-full max-w-[420px] border',
          cierreBlockers.length > 0 ? 'border-red-500/40' : 'border-green-500/30']">
          <div :class="['font-display text-[1.1rem] font-black mb-1',
            cierreBlockers.length > 0 ? 'text-red-400' : 'text-green-400']">Cierre de caja</div>
          <div class="text-[.7rem] text-gray-500 mb-4">{{ formatDate(currentDate) }}</div>

          <!-- Bloqueadores -->
          <div v-if="cierreBlockers.length > 0" class="mb-4">
            <div v-for="b in cierreBlockers" :key="b"
              class="flex items-start gap-2 bg-red-500/10 border border-red-500/30 rounded-lg px-3 py-2.5 mb-2">
              <span class="text-red-400 text-[1rem] leading-none flex-shrink-0">⚠</span>
              <span class="text-[.78rem] text-red-300 leading-snug">{{ b }}</span>
            </div>
            <div class="text-[.72rem] text-gray-500 text-center mt-3">Resolvé estos problemas antes de cerrar la caja.</div>
          </div>

          <!-- Resumen si no hay bloqueos -->
          <template v-else>
            <div class="bg-white/[.04] border border-gold/[.1] rounded-lg px-4 py-3 mb-3">
              <div class="flex justify-between items-center">
                <span class="text-[.72rem] text-gray-500">Total del día</span>
                <span class="font-display text-[1.15rem] font-black text-gold">${{ cierreData.total.toLocaleString('es-AR') }}</span>
              </div>
            </div>
            <textarea v-model="cierreNotas" placeholder="Notas del cierre (opcional)..."
              class="w-full bg-white/[.05] border border-gold/[.18] text-[#ccc] text-[.8rem] px-2.5 py-2.5 rounded-lg resize-none h-[64px] mb-3 focus:outline-none"
              style="font-family:inherit"
            ></textarea>
          </template>

          <div class="flex gap-2">
            <button @click="cierreVisible = false"
              class="px-4 py-3 text-gray-500 border border-gold/[.18] rounded-lg text-[.85rem] bg-transparent cursor-pointer">Cerrar</button>
            <button v-if="cierreBlockers.length === 0" @click="confirmCierre" :disabled="cierreLoading"
              class="flex-1 py-3 bg-[#2a6f2a] text-white border-none rounded-lg font-bold text-[.85rem] cursor-pointer disabled:opacity-50">
              {{ cierreLoading ? 'Guardando...' : 'Confirmar cierre' }}
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </div>
</template>

<style scoped>
.fade-enter-active, .fade-leave-active { transition: opacity .2s ease; }
.fade-enter-from, .fade-leave-to { opacity: 0; }
</style>
