import { createRouter, createWebHashHistory } from 'vue-router'
import { useAuthStore } from '@/stores/auth.store'
import type { Rol } from '@/types/domain'

// Páginas — lazy loaded para mejor performance
const LoginPage   = () => import('@/pages/LoginPage.vue')
const MesasPage   = () => import('@/pages/MesasPage.vue')
const KitchenPage = () => import('@/pages/KitchenPage.vue')
const ReportsPage = () => import('@/pages/ReportsPage.vue')

declare module 'vue-router' {
  interface RouteMeta {
    roles?: Rol[]
    requiresAuth?: boolean
  }
}

const router = createRouter({
  history: createWebHashHistory(),
  routes: [
    {
      path: '/',
      redirect: '/login',
    },
    {
      path: '/login',
      name: 'login',
      component: LoginPage,
    },
    {
      path: '/mesas',
      name: 'mesas',
      component: MesasPage,
      meta: { requiresAuth: true, roles: ['moza', 'caja', 'dueno'] },
    },
    {
      path: '/cocina',
      name: 'cocina',
      component: KitchenPage,
      meta: { requiresAuth: true, roles: ['cocina', 'dueno'] },
    },
    {
      path: '/reportes',
      name: 'reportes',
      component: ReportsPage,
      meta: { requiresAuth: true, roles: ['caja', 'dueno'] },
    },
    {
      path: '/:pathMatch(.*)*',
      redirect: '/login',
    },
  ],
})

// ── NAVIGATION GUARD ───────────────────────────────────────────────────────
router.beforeEach(async (to) => {
  const auth = useAuthStore()

  // Esperar a que se cargue el estado de auth en el primer acceso
  if (auth.loading) await auth.init()

  if (!to.meta.requiresAuth) return true

  if (!auth.isAuthenticated) return { name: 'login' }

  if (to.meta.roles && !auth.can(...(to.meta.roles as Rol[]))) {
    // Redirigir según rol
    const destino: Record<Rol, string> = {
      moza:   'mesas',
      caja:   'mesas',
      dueno:  'mesas',
      cocina: 'cocina',
    }
    return { name: destino[auth.rol as Rol] ?? 'login' }
  }

  return true
})

export default router
