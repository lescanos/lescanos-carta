<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { supabase } from '@/services/supabase'
import { useAuthStore } from '@/stores/auth.store'
import { useBrandStore } from '@/stores/brand.store'
import type { Perfil, Rol } from '@/types/domain'

const router  = useRouter()
const auth    = useAuthStore()
const brand   = useBrandStore()

const perfiles     = ref<Perfil[]>([])
const selected     = ref<Perfil | null>(null)
const password     = ref('')
const loading      = ref(false)
const loadingPerfs = ref(true)
const error        = ref('')

const ROL_DESTINO: Record<Rol, string> = {
  moza:   'mesas',
  caja:   'mesas',
  dueno:  'mesas',
  cocina: 'cocina',
}

onMounted(async () => {
  // Si ya hay sesión activa, redirigir
  if (auth.isAuthenticated) {
    router.replace({ name: ROL_DESTINO[auth.rol!] ?? 'mesas' })
    return
  }

  // Garantiza que la brand config (incluyendo emailDomain) esté cargada antes
  // de mostrar el formulario. Sin esto, el login puede usar el dominio del cache
  // viejo de localStorage antes de que llegue la respuesta de Supabase.
  await brand.init()

  const { data } = await supabase
    .from('perfiles_publicos')
    .select('id, nombre, login_key, emoji, activo')
    .order('nombre')

  perfiles.value = (data as Perfil[]) ?? []
  loadingPerfs.value = false
})

function selectPerfil(perfil: Perfil) {
  selected.value = perfil
  password.value = ''
  error.value = ''
}

async function login() {
  if (!selected.value || !password.value) return
  loading.value = true
  error.value = ''

  const email = `${selected.value.login_key}@${brand.config.emailDomain}`
  const { error: authError } = await supabase.auth.signInWithPassword({ email, password: password.value })

  if (authError) {
    error.value = 'Contraseña incorrecta'
    loading.value = false
    return
  }

  await auth.loadProfile(selected.value.id)
  loading.value = false

  const destino = ROL_DESTINO[selected.value.rol] ?? 'mesas'
  router.replace({ name: destino })
}
</script>

<template>
  <div class="min-h-screen bg-dark flex flex-col items-center justify-center p-6">
    <!-- Brand -->
    <div class="font-display text-4xl font-black text-gold tracking-widest mb-2">{{ brand.config.nombre }}</div>
    <div class="text-xs text-gray-500 tracking-[.22em] uppercase mb-10">Sistema de gestión</div>

    <!-- Selección de perfil -->
    <template v-if="!selected">
      <div class="text-xs text-gray-500 tracking-[.18em] uppercase mb-4">¿Quién sos?</div>
      <div v-if="loadingPerfs" class="text-gray-500 text-sm">Cargando...</div>
      <div v-else class="grid grid-cols-2 gap-3 w-full max-w-xs">
        <button
          v-for="p in perfiles"
          :key="p.id"
          @click="selectPerfil(p)"
          class="bg-dark2 border border-gold/20 rounded-2xl p-5 flex flex-col items-center gap-2
                 active:bg-dark2/80 active:border-gold/40 transition-colors"
        >
          <span class="text-3xl">{{ p.emoji }}</span>
          <span class="text-sm font-bold text-white">{{ p.nombre }}</span>
        </button>
      </div>
    </template>

    <!-- Ingreso de contraseña -->
    <template v-else>
      <div class="w-full max-w-xs">
        <button @click="selected = null" class="text-gold/60 text-xs tracking-widest mb-6 flex items-center gap-1">
          ‹ Volver
        </button>

        <div class="text-center mb-6">
          <div class="text-4xl mb-2">{{ selected.emoji }}</div>
          <div class="text-xl font-bold text-white">{{ selected.nombre }}</div>
        </div>

        <input
          v-model="password"
          type="password"
          placeholder="Contraseña"
          autocomplete="current-password"
          @keyup.enter="login"
          class="w-full bg-white/5 border border-gold/20 rounded-xl px-4 py-3 text-white
                 text-base focus:outline-none focus:border-gold/50 mb-3"
        />

        <p v-if="error" class="text-red-400 text-xs text-center mb-3">{{ error }}</p>

        <button
          @click="login"
          :disabled="loading || !password"
          class="w-full bg-gold text-dark font-bold py-3 rounded-xl tracking-wide
                 disabled:opacity-40 active:opacity-80 transition-opacity"
        >
          {{ loading ? 'Ingresando...' : 'Ingresar' }}
        </button>
      </div>
    </template>
  </div>
</template>
