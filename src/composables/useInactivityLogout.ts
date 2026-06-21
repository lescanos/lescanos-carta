import { onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import { useAuthStore } from '@/stores/auth.store'

const INACTIVITY_EVENTS = ['pointerdown', 'keydown', 'scroll'] as const

/**
 * Auto-logout after `timeoutMs` ms of no user interaction.
 * Add to any protected page that should enforce inactivity timeout.
 * Do NOT add to KitchenPage — it must stay active indefinitely.
 */
export function useInactivityLogout(timeoutMs = 60 * 60 * 1000) {
  const auth   = useAuthStore()
  const router = useRouter()

  let timer: ReturnType<typeof setTimeout> | null = null

  function resetTimer() {
    if (timer) clearTimeout(timer)
    timer = setTimeout(async () => {
      await auth.logout()
      router.replace({ name: 'login' })
    }, timeoutMs)
  }

  onMounted(() => {
    INACTIVITY_EVENTS.forEach(e => document.addEventListener(e, resetTimer, { passive: true }))
    resetTimer()
  })

  onUnmounted(() => {
    INACTIVITY_EVENTS.forEach(e => document.removeEventListener(e, resetTimer))
    if (timer) clearTimeout(timer)
  })
}
