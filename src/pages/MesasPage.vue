<script setup lang="ts">
import { useAuthStore } from '@/stores/auth.store'
import { useRouter } from 'vue-router'

const auth   = useAuthStore()
const router = useRouter()
</script>

<template>
  <div class="h-screen bg-dark flex flex-col">
    <!-- Header -->
    <header class="bg-dark2 border-b border-gold/20 px-4 py-3 flex items-center gap-2 flex-shrink-0">
      <span class="font-display font-black text-gold tracking-widest text-lg">Lescano's</span>
      <span class="text-xs text-gray-500 tracking-widest ml-1">MESAS</span>
      <div class="ml-auto flex items-center gap-3">
        <span class="text-xs text-gray-400">{{ auth.currentUser?.nombre }}</span>
        <button
          v-if="auth.can('caja', 'dueno')"
          @click="router.push({ name: 'reportes' })"
          class="text-xs border border-gold/30 text-gold/70 px-2 py-1 rounded"
        >
          Reportes
        </button>
        <button @click="auth.logout().then(() => router.replace({ name: 'login' }))"
          class="text-xs border border-white/10 text-gray-500 px-2 py-1 rounded">
          Salir
        </button>
      </div>
    </header>

    <!-- Placeholder hasta que migremos esta pantalla -->
    <div class="flex-1 flex items-center justify-center text-gray-600 text-sm">
      MesasPage — en construcción
    </div>
  </div>
</template>
