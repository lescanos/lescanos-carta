import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from '@/services/supabase'
import type { CurrentUser, Rol } from '@/types/domain'

export const useAuthStore = defineStore('auth', () => {
  const currentUser = ref<CurrentUser | null>(null)
  const loading     = ref(true)

  const isAuthenticated = computed(() => currentUser.value !== null)
  const rol             = computed(() => currentUser.value?.rol ?? null)

  function can(...roles: Rol[]): boolean {
    return roles.includes(currentUser.value?.rol as Rol)
  }

  async function init() {
    loading.value = true
    const { data: { session } } = await supabase.auth.getSession()
    if (session) await loadProfile(session.user.id)
    loading.value = false
  }

  async function loadProfile(userId: string) {
    const { data, error } = await supabase
      .from('perfiles')
      .select('id, nombre, rol, activo')
      .eq('id', userId)
      .single()

    if (error || !data || !data.activo) {
      currentUser.value = null
      return
    }

    currentUser.value = {
      id:     data.id,
      nombre: data.nombre,
      rol:    data.rol as Rol,
    }
  }

  async function logout() {
    await supabase.auth.signOut()
    currentUser.value = null
  }

  return { currentUser, loading, isAuthenticated, rol, can, init, loadProfile, logout }
})
