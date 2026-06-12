import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import { fileURLToPath, URL } from 'node:url'

export default defineConfig({
  plugins: [vue()],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
  // GitHub Pages despliega en /lescanos-carta/ — ajustar si el repo cambia de nombre
  base: process.env.NODE_ENV === 'production' ? '/lescanos-carta/' : '/',
})
