<script setup lang="ts">
import { watch } from 'vue'
import { RouterView } from 'vue-router'
import { useBrandStore } from '@/stores/brand.store'

const brand = useBrandStore()
brand.init()

// Actualiza el <title> cuando carga la marca
watch(
  () => brand.config.nombre,
  (nombre) => { document.title = nombre },
  { immediate: true }
)
</script>

<template>
  <RouterView />
</template>
