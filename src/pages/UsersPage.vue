<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/services/supabase'

const router = useRouter()

// ── TABS ──────────────────────────────────────────────────────────────────
type Tab = 'usuarios' | 'menu' | 'config'
const activeTab = ref<Tab>('usuarios')

// ── TOAST ─────────────────────────────────────────────────────────────────
const toastMsg = ref('')
let toastTimer: ReturnType<typeof setTimeout> | null = null
function showToast(msg: string) {
  toastMsg.value = msg
  if (toastTimer) clearTimeout(toastTimer)
  toastTimer = setTimeout(() => { toastMsg.value = '' }, 2500)
}

// ══════════════════════════════════════════════════════════════════════════
// TAB: USUARIOS
// ══════════════════════════════════════════════════════════════════════════
interface Perfil {
  id: string; nombre: string; login_key: string; rol: string; emoji: string; activo: boolean
}

const perfiles    = ref<Perfil[]>([])
const loadingU    = ref(true)
const editVisible = ref(false)
const editPerfil  = ref<Perfil | null>(null)
const editNombre  = ref('')
const editKey     = ref('')
const editRol     = ref('')
const editEmoji   = ref('')
const editSaving  = ref(false)
const pwdVisible  = ref(false)
const pwdUserId   = ref('')
const pwdNombre   = ref('')
const pwdValue    = ref('')
const pwdSaving   = ref(false)
const newVisible  = ref(false)
const newNombre   = ref('')
const newKey      = ref('')
const newRol      = ref('moza')
const newEmoji    = ref('🧑')
const newPwd      = ref('')
const newSaving   = ref(false)

const ROLES  = [
  { id: 'moza', label: 'Moza', icon: '🧑‍💼' },
  { id: 'cocina', label: 'Cocina', icon: '🍳' },
  { id: 'caja', label: 'Caja', icon: '💵' },
  { id: 'dueno', label: 'Dueño', icon: '👑' },
]
const EMOJIS = ['🧑‍💼','🍳','💵','👑','🧑','👨‍🍳','👩‍🍳','🧑‍💻','🧑‍🔧','🌟']

async function loadPerfiles() {
  loadingU.value = true
  const { data } = await supabase.from('perfiles').select('*').order('nombre')
  perfiles.value = (data as Perfil[]) ?? []
  loadingU.value = false
}

async function callAdminFn(body: object): Promise<{ ok: boolean; error?: string; data?: unknown }> {
  const { data: { session } } = await supabase.auth.getSession()
  if (!session) return { ok: false, error: 'No hay sesión activa' }
  const url = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/admin-users`
  const res  = await fetch(url, {
    method: 'POST',
    headers: { 'Authorization': `Bearer ${session.access_token}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  })
  const json = await res.json()
  if (!res.ok) return { ok: false, error: json.error || 'Error desconocido' }
  return { ok: true, data: json }
}

async function toggleActivo(p: Perfil) {
  const { error } = await supabase.from('perfiles').update({ activo: !p.activo }).eq('id', p.id)
  if (error) { showToast('Error al actualizar'); return }
  p.activo = !p.activo
  showToast(p.activo ? `${p.nombre} activado ✓` : `${p.nombre} desactivado`)
}

function openEdit(p: Perfil) {
  editPerfil.value = p; editNombre.value = p.nombre; editKey.value = p.login_key
  editRol.value = p.rol; editEmoji.value = p.emoji; editVisible.value = true
}
async function saveEdit() {
  if (!editPerfil.value) return
  if (!editNombre.value.trim() || !editKey.value.trim()) { showToast('Nombre y clave son requeridos'); return }
  editSaving.value = true
  const { error } = await supabase.from('perfiles').update({
    nombre: editNombre.value.trim(), login_key: editKey.value.trim().toLowerCase(),
    rol: editRol.value, emoji: editEmoji.value,
  }).eq('id', editPerfil.value.id)
  editSaving.value = false
  if (error) { showToast('Error al guardar: ' + error.message); return }
  await loadPerfiles(); editVisible.value = false; showToast('Perfil actualizado ✓')
}

function openPwd(p: Perfil) {
  pwdUserId.value = p.id; pwdNombre.value = p.nombre; pwdValue.value = ''; pwdVisible.value = true
}
async function savePwd() {
  if (pwdValue.value.length < 6) { showToast('La contraseña debe tener al menos 6 caracteres'); return }
  pwdSaving.value = true
  const { ok, error } = await callAdminFn({ action: 'resetPassword', userId: pwdUserId.value, data: { password: pwdValue.value } })
  pwdSaving.value = false
  if (!ok) { showToast('Error: ' + error); return }
  pwdVisible.value = false; showToast(`Contraseña de ${pwdNombre.value} actualizada ✓`)
}

function openNew() {
  newNombre.value = ''; newKey.value = ''; newRol.value = 'moza'
  newEmoji.value = '🧑‍💼'; newPwd.value = ''; newVisible.value = true
}
async function createUser() {
  if (!newNombre.value.trim() || !newKey.value.trim()) { showToast('Nombre y clave son requeridos'); return }
  if (newPwd.value.length < 6) { showToast('La contraseña debe tener al menos 6 caracteres'); return }
  newSaving.value = true
  const { ok, error } = await callAdminFn({
    action: 'createUser',
    data: { nombre: newNombre.value.trim(), login_key: newKey.value.trim().toLowerCase(), rol: newRol.value, emoji: newEmoji.value, password: newPwd.value },
  })
  newSaving.value = false
  if (!ok) { showToast('Error: ' + error); return }
  await loadPerfiles(); newVisible.value = false; showToast(`${newNombre.value} creado ✓`)
}
async function deleteUser(p: Perfil) {
  if (!confirm(`¿Eliminar a ${p.nombre} permanentemente? Esta acción no se puede deshacer.`)) return
  const { ok, error } = await callAdminFn({ action: 'deleteUser', userId: p.id, data: {} })
  if (!ok) { showToast('Error: ' + error); return }
  await loadPerfiles(); showToast(`${p.nombre} eliminado`)
}

// ══════════════════════════════════════════════════════════════════════════
// TAB: MENÚ
// ══════════════════════════════════════════════════════════════════════════
interface MenuItemEditable {
  id: string
  nombre: string
  descripcion: string
  precios: string[]
  columnas: string[] | null
  saving: boolean
}
interface SeccionDisplay {
  id: string
  pagina: number
  pagina_titulo: string
  pagina_tipo: string
  emoji: string | null
  titulo: string
  nota: string | null
  columnas: string[] | null
  items: MenuItemEditable[]
}

const menuSecciones = ref<SeccionDisplay[]>([])
const menuLoading   = ref(false)
const menuLoaded    = ref(false)

async function loadMenu() {
  menuLoading.value = true
  const [{ data: secs }, { data: items }] = await Promise.all([
    supabase.from('menu_secciones').select('id,pagina,pagina_titulo,pagina_tipo,seccion_orden,emoji,titulo,nota,columnas').order('pagina').order('seccion_orden'),
    supabase.from('menu_items').select('id,seccion_id,item_orden,nombre,descripcion,precios').order('seccion_id').order('item_orden'),
  ])
  if (!secs || !items) { menuLoading.value = false; return }

  const itemsBySec = new Map<string, typeof items>()
  for (const item of items) {
    if (!itemsBySec.has(item.seccion_id)) itemsBySec.set(item.seccion_id, [])
    itemsBySec.get(item.seccion_id)!.push(item)
  }

  menuSecciones.value = secs.map(s => ({
    id: s.id as string,
    pagina: s.pagina as number,
    pagina_titulo: s.pagina_titulo as string,
    pagina_tipo: s.pagina_tipo as string,
    emoji: s.emoji as string | null,
    titulo: s.titulo as string,
    nota: s.nota as string | null,
    columnas: s.columnas as string[] | null,
    items: (itemsBySec.get(s.id as string) ?? []).map(item => ({
      id: item.id as string,
      nombre: item.nombre as string,
      descripcion: (item.descripcion ?? '') as string,
      precios: [...(item.precios as string[])],
      columnas: s.columnas as string[] | null,
      saving: false,
    })),
  }))

  menuLoading.value = false
  menuLoaded.value  = true
}

function switchTab(tab: Tab) {
  activeTab.value = tab
  if (tab === 'menu' && !menuLoaded.value) loadMenu()
}

async function saveItemPrecios(item: MenuItemEditable) {
  item.saving = true
  const { error } = await supabase.from('menu_items').update({ precios: item.precios }).eq('id', item.id)
  item.saving = false
  if (error) showToast('Error al guardar precio')
  else showToast('Precio actualizado ✓')
}

// ══════════════════════════════════════════════════════════════════════════
// TAB: CONFIGURACIÓN
// ══════════════════════════════════════════════════════════════════════════
const costoEnvioEdit   = ref('')
const costoEnvioSaving = ref(false)

async function loadConfig() {
  const { data } = await supabase.from('config').select('clave,valor').eq('clave', 'costo_envio').single()
  costoEnvioEdit.value = data?.valor ?? '0'
}
async function saveCostoEnvio() {
  const val = parseInt(costoEnvioEdit.value) || 0
  costoEnvioSaving.value = true
  const { error } = await supabase.from('config').upsert({ clave: 'costo_envio', valor: String(val) }, { onConflict: 'clave' })
  costoEnvioSaving.value = false
  if (error) { showToast('Error al guardar: ' + error.message); return }
  showToast('Costo de envío actualizado ✓')
}

onMounted(async () => {
  await loadPerfiles()
  await loadConfig()
})
</script>

<template>
  <div class="fixed inset-0 flex flex-col bg-dark text-white overflow-hidden">

    <!-- Header -->
    <header class="bg-dark2 border-b border-gold/[.18] px-4 py-3 flex items-center gap-2 flex-shrink-0 min-h-[52px]">
      <button @click="router.replace({ name: 'mesas' })"
        class="text-gold text-2xl leading-none px-1 pr-2 bg-transparent border-none cursor-pointer">‹</button>
      <span class="font-display text-[1rem] font-black text-gold tracking-[.06em] flex-1">Administración</span>
      <button v-if="activeTab === 'usuarios'" @click="openNew"
        class="text-[.7rem] font-bold bg-gold text-dark px-3 py-1.5 rounded-lg tracking-[.04em] border-none cursor-pointer">
        + Nuevo
      </button>
    </header>

    <!-- Tabs -->
    <div class="flex border-b border-white/[.06] bg-dark2 flex-shrink-0">
      <button v-for="tab in [['usuarios','Usuarios'],['menu','Menú'],['config','Config']] as [Tab, string][]"
        :key="tab[0]"
        @click="switchTab(tab[0])"
        :class="['flex-1 py-2.5 text-[.72rem] font-bold tracking-[.06em] uppercase border-none cursor-pointer transition-colors',
          activeTab === tab[0]
            ? 'text-gold bg-dark border-b-2 border-gold'
            : 'text-gray-500 bg-dark2']">
        {{ tab[1] }}
      </button>
    </div>

    <!-- Content -->
    <div class="flex-1 overflow-y-auto">

      <!-- ══ USUARIOS ══ -->
      <template v-if="activeTab === 'usuarios'">
        <div v-if="loadingU" class="p-10 text-center text-gray-500 text-[.85rem]">Cargando...</div>
        <div v-else-if="perfiles.length === 0" class="p-10 text-center text-gray-500 text-[.85rem]">No hay usuarios.</div>
        <div v-else>
          <div v-for="p in perfiles" :key="p.id"
            :class="['flex items-center px-4 py-3.5 border-b border-white/[.05] gap-3', !p.activo && 'opacity-40']">
            <div class="text-2xl flex-shrink-0">{{ p.emoji }}</div>
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-2">
                <span class="text-[.92rem] font-bold text-white">{{ p.nombre }}</span>
                <span class="text-[.55rem] text-gold/60 border border-gold/20 px-1.5 py-0.5 rounded tracking-[.08em] uppercase">
                  {{ ROLES.find(r => r.id === p.rol)?.label ?? p.rol }}
                </span>
                <span v-if="!p.activo" class="text-[.55rem] text-red-400/60 border border-red-400/20 px-1.5 py-0.5 rounded tracking-[.08em] uppercase">Inactivo</span>
              </div>
              <div class="text-[.7rem] text-gray-500 mt-0.5">Clave: <span class="text-gray-400 font-mono">{{ p.login_key }}</span></div>
            </div>
            <div class="flex gap-1.5 flex-shrink-0">
              <button @click="toggleActivo(p)"
                :class="['text-[.65rem] px-2 py-1 rounded border cursor-pointer tracking-[.03em]',
                  p.activo ? 'text-red-400/70 border-red-400/20 bg-transparent' : 'text-green-400/70 border-green-400/20 bg-transparent']">
                {{ p.activo ? 'Desactivar' : 'Activar' }}
              </button>
              <button @click="openPwd(p)" class="text-[.65rem] px-2 py-1 rounded border border-gold/20 text-gold/60 bg-transparent cursor-pointer">🔑</button>
              <button @click="openEdit(p)" class="text-[.65rem] px-2 py-1 rounded border border-gold/20 text-gold/60 bg-transparent cursor-pointer">✎</button>
              <button @click="deleteUser(p)" class="text-[.65rem] px-2 py-1 rounded border border-red-500/20 text-red-400/50 bg-transparent cursor-pointer">✕</button>
            </div>
          </div>
        </div>
      </template>

      <!-- ══ MENÚ ══ -->
      <template v-else-if="activeTab === 'menu'">
        <div v-if="menuLoading" class="p-10 text-center text-gray-500 text-[.85rem]">Cargando menú...</div>
        <div v-else>
          <div class="px-4 pt-4 pb-2 text-[.6rem] text-gray-500 tracking-[.18em] uppercase">
            Tocá un precio para editarlo — se guarda automáticamente al salir del campo
          </div>

          <template v-for="sec in menuSecciones" :key="sec.id">
            <!-- Separador de página -->
            <div class="px-4 pt-4 pb-1 flex items-center gap-2">
              <div class="text-[.58rem] text-gold/40 tracking-[.16em] uppercase">{{ sec.pagina_titulo }}</div>
              <div class="flex-1 h-px bg-gold/10"></div>
            </div>

            <!-- Header de sección -->
            <div class="px-4 py-2 bg-dark2/50 border-y border-white/[.04] flex items-center gap-2">
              <span class="text-base">{{ sec.emoji }}</span>
              <div>
                <span class="text-[.8rem] font-bold text-gold tracking-[.05em]">{{ sec.titulo || sec.pagina_titulo }}</span>
                <span v-if="sec.nota" class="text-[.65rem] text-gray-500 ml-2">{{ sec.nota }}</span>
              </div>
            </div>

            <!-- Encabezado de columnas -->
            <div v-if="sec.columnas" class="flex items-center px-4 py-1 border-b border-white/[.04]">
              <div class="flex-1 text-[.58rem] text-gray-600 uppercase tracking-widest">Producto</div>
              <div v-for="col in sec.columnas" :key="col"
                class="w-[72px] text-center text-[.58rem] text-gray-600 uppercase tracking-widest">
                {{ col }}
              </div>
            </div>

            <!-- Items -->
            <div v-for="item in sec.items" :key="item.id"
              class="flex items-center px-4 py-2.5 border-b border-white/[.04] gap-3">
              <div class="flex-1 min-w-0">
                <div class="text-[.82rem] font-bold text-white truncate">{{ item.nombre }}</div>
                <div v-if="item.descripcion" class="text-[.62rem] text-gray-500 truncate mt-0.5">{{ item.descripcion }}</div>
              </div>
              <!-- Inputs de precio (uno por columna) -->
              <div class="flex gap-1.5 flex-shrink-0 items-center">
                <input
                  v-for="(_, idx) in item.precios"
                  :key="idx"
                  v-model="item.precios[idx]"
                  @blur="saveItemPrecios(item)"
                  :disabled="item.saving"
                  class="w-[72px] bg-white/[.06] border border-gold/[.18] text-gold text-[.82rem] font-bold
                         px-2 py-1.5 rounded-lg text-center focus:outline-none focus:border-gold/60
                         disabled:opacity-40 font-mono"
                />
                <span v-if="item.saving" class="text-[.65rem] text-gray-500 w-3">…</span>
              </div>
            </div>
          </template>

          <div class="h-6"></div>
        </div>
      </template>

      <!-- ══ CONFIG ══ -->
      <template v-else-if="activeTab === 'config'">
        <div class="px-4 pt-5 pb-4">
          <div class="text-[.6rem] text-gray-500 tracking-[.18em] uppercase mb-3">Configuración</div>
          <div class="bg-dark2 border border-gold/[.15] rounded-xl px-4 py-3.5 flex items-center gap-3">
            <div class="flex-1">
              <div class="text-[.85rem] font-bold text-white">🛵 Costo de envío</div>
              <div class="text-[.65rem] text-gray-500 mt-0.5">Se suma a todos los pedidos de envío a domicilio</div>
            </div>
            <div class="flex items-center gap-2 flex-shrink-0">
              <span class="text-[.9rem] text-gold font-mono">$</span>
              <input v-model="costoEnvioEdit" type="number" min="0" step="100"
                class="w-[90px] bg-white/[.06] border border-gold/[.18] text-gold text-[.9rem] font-bold px-2.5 py-1.5 rounded-[8px] focus:outline-none focus:border-gold/50 text-right" />
              <button @click="saveCostoEnvio" :disabled="costoEnvioSaving"
                class="text-[.72rem] font-bold bg-gold text-dark px-3 py-1.5 rounded-lg border-none cursor-pointer disabled:opacity-50">
                {{ costoEnvioSaving ? '...' : 'Guardar' }}
              </button>
            </div>
          </div>
        </div>
      </template>

    </div><!-- /content -->

    <!-- ══ EDIT MODAL ══ -->
    <Transition name="sheet">
      <div v-if="editVisible" class="fixed inset-0 bg-black/72 z-50 flex items-end" @click.self="editVisible = false">
        <div class="w-full bg-[#1a1a1a] rounded-t-[22px] border-t border-gold/30 pt-2 pb-10 max-h-[92vh] overflow-y-auto">
          <div class="w-10 h-1 rounded-full bg-white/15 mx-auto mb-4"></div>
          <div class="font-display text-[1rem] font-black text-gold text-center tracking-[.06em] pb-3 border-b border-white/[.06]">Editar perfil</div>
          <div class="flex flex-wrap gap-2 justify-center px-5 pt-4 pb-2">
            <button v-for="e in EMOJIS" :key="e" @click="editEmoji = e"
              :class="['text-xl w-10 h-10 rounded-xl border-2 flex items-center justify-center cursor-pointer transition-colors',
                editEmoji === e ? 'border-gold bg-gold/[.1]' : 'border-gold/10 bg-transparent']">{{ e }}</button>
          </div>
          <div class="px-4 pt-2 space-y-2.5">
            <input v-model="editNombre" placeholder="Nombre"
              class="block w-full bg-white/[.06] border border-gold/[.18] text-white text-[.9rem] px-3 py-2.5 rounded-[10px] focus:outline-none focus:border-gold/50" />
            <input v-model="editKey" placeholder="Clave de login (ej: maria)"
              class="block w-full bg-white/[.06] border border-gold/[.18] text-white text-[.9rem] px-3 py-2.5 rounded-[10px] focus:outline-none focus:border-gold/50 font-mono" />
            <div class="grid grid-cols-2 gap-2">
              <button v-for="r in ROLES" :key="r.id" @click="editRol = r.id"
                :class="['py-2.5 rounded-[10px] text-[.78rem] font-bold border-[1.5px] cursor-pointer transition-colors',
                  editRol === r.id ? 'border-gold bg-gold/[.12] text-gold' : 'border-gold/15 text-gray-400 bg-transparent']">
                {{ r.icon }} {{ r.label }}
              </button>
            </div>
          </div>
          <button @click="saveEdit" :disabled="editSaving"
            class="block w-[calc(100%-32px)] mx-4 mt-4 py-3.5 bg-gold text-dark font-bold text-[.9rem] rounded-[10px] tracking-[.04em] cursor-pointer border-none disabled:opacity-45">
            {{ editSaving ? 'Guardando...' : 'Guardar cambios' }}
          </button>
          <button @click="editVisible = false"
            class="block w-[calc(100%-32px)] mx-4 mt-2 py-2.5 text-white/35 border border-white/10 rounded-lg text-[.82rem] bg-transparent cursor-pointer">Cancelar</button>
        </div>
      </div>
    </Transition>

    <!-- ══ PASSWORD MODAL ══ -->
    <Transition name="sheet">
      <div v-if="pwdVisible" class="fixed inset-0 bg-black/72 z-50 flex items-end" @click.self="pwdVisible = false">
        <div class="w-full bg-[#1a1a1a] rounded-t-[22px] border-t border-gold/30 pt-2 pb-10">
          <div class="w-10 h-1 rounded-full bg-white/15 mx-auto mb-4"></div>
          <div class="text-[.9rem] font-bold text-white text-center pb-1">Cambiar contraseña</div>
          <div class="text-[.65rem] text-gray-500 text-center pb-4 border-b border-white/[.06]">{{ pwdNombre }}</div>
          <div class="px-4 pt-4">
            <input v-model="pwdValue" type="password" placeholder="Nueva contraseña (mín. 6 caracteres)"
              class="block w-full bg-white/[.06] border border-gold/[.18] text-white text-[.9rem] px-3 py-2.5 rounded-[10px] focus:outline-none focus:border-gold/50" />
          </div>
          <button @click="savePwd" :disabled="pwdSaving"
            class="block w-[calc(100%-32px)] mx-4 mt-4 py-3.5 bg-gold text-dark font-bold text-[.9rem] rounded-[10px] tracking-[.04em] cursor-pointer border-none disabled:opacity-45">
            {{ pwdSaving ? 'Guardando...' : 'Cambiar contraseña' }}
          </button>
          <button @click="pwdVisible = false"
            class="block w-[calc(100%-32px)] mx-4 mt-2 py-2.5 text-white/35 border border-white/10 rounded-lg text-[.82rem] bg-transparent cursor-pointer">Cancelar</button>
        </div>
      </div>
    </Transition>

    <!-- ══ NEW USER MODAL ══ -->
    <Transition name="sheet">
      <div v-if="newVisible" class="fixed inset-0 bg-black/72 z-50 flex items-end" @click.self="newVisible = false">
        <div class="w-full bg-[#1a1a1a] rounded-t-[22px] border-t border-gold/30 pt-2 pb-10 max-h-[92vh] overflow-y-auto">
          <div class="w-10 h-1 rounded-full bg-white/15 mx-auto mb-4"></div>
          <div class="font-display text-[1rem] font-black text-gold text-center tracking-[.06em] pb-3 border-b border-white/[.06]">Nuevo usuario</div>
          <div class="flex flex-wrap gap-2 justify-center px-5 pt-4 pb-2">
            <button v-for="e in EMOJIS" :key="e" @click="newEmoji = e"
              :class="['text-xl w-10 h-10 rounded-xl border-2 flex items-center justify-center cursor-pointer transition-colors',
                newEmoji === e ? 'border-gold bg-gold/[.1]' : 'border-gold/10 bg-transparent']">{{ e }}</button>
          </div>
          <div class="px-4 pt-2 space-y-2.5">
            <input v-model="newNombre" placeholder="Nombre (ej: Sofía)"
              class="block w-full bg-white/[.06] border border-gold/[.18] text-white text-[.9rem] px-3 py-2.5 rounded-[10px] focus:outline-none focus:border-gold/50" />
            <input v-model="newKey" placeholder="Clave de login (ej: sofia)"
              class="block w-full bg-white/[.06] border border-gold/[.18] text-white text-[.9rem] px-3 py-2.5 rounded-[10px] focus:outline-none focus:border-gold/50 font-mono" />
            <input v-model="newPwd" type="password" placeholder="Contraseña inicial (mín. 6 caracteres)"
              class="block w-full bg-white/[.06] border border-gold/[.18] text-white text-[.9rem] px-3 py-2.5 rounded-[10px] focus:outline-none focus:border-gold/50" />
            <div class="grid grid-cols-2 gap-2">
              <button v-for="r in ROLES" :key="r.id" @click="newRol = r.id"
                :class="['py-2.5 rounded-[10px] text-[.78rem] font-bold border-[1.5px] cursor-pointer transition-colors',
                  newRol === r.id ? 'border-gold bg-gold/[.12] text-gold' : 'border-gold/15 text-gray-400 bg-transparent']">
                {{ r.icon }} {{ r.label }}
              </button>
            </div>
          </div>
          <button @click="createUser" :disabled="newSaving"
            class="block w-[calc(100%-32px)] mx-4 mt-4 py-3.5 bg-gold text-dark font-bold text-[.9rem] rounded-[10px] tracking-[.04em] cursor-pointer border-none disabled:opacity-45">
            {{ newSaving ? 'Creando...' : 'Crear usuario' }}
          </button>
          <button @click="newVisible = false"
            class="block w-[calc(100%-32px)] mx-4 mt-2 py-2.5 text-white/35 border border-white/10 rounded-lg text-[.82rem] bg-transparent cursor-pointer">Cancelar</button>
        </div>
      </div>
    </Transition>

    <!-- Toast -->
    <Transition name="toastfade">
      <div v-if="toastMsg"
        class="fixed bottom-8 left-1/2 -translate-x-1/2 bg-[rgba(40,40,40,.96)] text-white
               px-[18px] py-2 rounded-[20px] text-[.8rem] tracking-[.04em] pointer-events-none
               z-[999] whitespace-nowrap border border-gold/[.18]">
        {{ toastMsg }}
      </div>
    </Transition>
  </div>
</template>

<style scoped>
.sheet-enter-active, .sheet-leave-active { transition: opacity .2s ease; }
.sheet-enter-from, .sheet-leave-to { opacity: 0; }
.toastfade-enter-active, .toastfade-leave-active { transition: opacity .3s ease; }
.toastfade-enter-from, .toastfade-leave-to { opacity: 0; }
</style>
