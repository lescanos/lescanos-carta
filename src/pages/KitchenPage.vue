<script setup lang="ts">
import { useAuthStore } from '@/stores/auth.store'
import { useRouter } from 'vue-router'

const auth   = useAuthStore()
const router = useRouter()
</script>

<template>
  <div class="h-screen bg-dark flex flex-col">
    <header class="bg-dark2 border-b border-gold/20 px-4 py-3 flex items-center gap-2 flex-shrink-0">
      <span class="font-display font-black text-gold tracking-widest text-lg">Lescano's</span>
      <span class="text-xs text-gray-500 tracking-widest ml-1">COCINA</span>
      <div class="ml-auto">
        <button @click="auth.logout().then(() => router.replace({ name: 'login' }))"
          class="text-xs border border-white/10 text-gray-500 px-2 py-1 rounded">
          Salir
        </button>
      </div>
    </header>
    <div class="flex-1 flex items-center justify-center text-gray-600 text-sm">
      KitchenPage — en construcción
    </div>
  </div>
</template>
