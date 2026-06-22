<template>
  <div class="carta-root">
    <!-- Carousel -->
    <div class="carousel" ref="carouselEl" @scroll.passive="onScroll">
      <template v-for="(page, pi) in carta" :key="pi">
        <!-- Promo slide -->
        <div v-if="page.tipo === 'promos'" class="slide slide-promo">
          <div class="promo-inner">
            <div class="promo-head">
              <div class="promo-brand">— {{ brand.config.nombre.toUpperCase() }} —</div>
              <div class="promo-big-title">PROMOS</div>
              <div v-if="page.subtitulo" class="promo-period">({{ page.subtitulo }})</div>
            </div>
            <div class="promo-list">
              <div v-for="(item, ii) in page.items" :key="ii" class="promo-card">
                <div class="promo-card-name">{{ item.nombre }}</div>
                <div class="promo-card-price">{{ item.precio }}</div>
              </div>
            </div>
            <div class="promo-efectivo">★ PRECIOS SOLO EN EFECTIVO ★</div>
          </div>
        </div>

        <!-- Regular slide -->
        <div v-else class="slide">
          <div class="panel-left">
            <div class="brand-name">{{ brand.config.nombre.toUpperCase() }}</div>
            <div class="brand-sub">{{ brand.config.subtitulo }}</div>
            <div class="gold-line" />
            <img class="logo-img" :src="logoSrc" :alt="`Logo ${brand.config.nombre}`" />
            <div class="gold-line" />
            <div class="contact-title">CONTACTO</div>
            <ul class="contact-list">
              <li v-if="brand.config.contactoDireccion">📍 {{ brand.config.contactoDireccion }}</li>
              <li v-if="brand.config.contactoTelefono">📱 {{ brand.config.contactoTelefono }}</li>
              <li v-if="brand.config.contactoInstagram">📸 {{ brand.config.contactoInstagram }}</li>
              <li v-if="brand.config.contactoFacebook">👥 {{ brand.config.contactoFacebook }}</li>
            </ul>
          </div>
          <div class="panel-right">
            <div class="right-header">
              <span class="carta-label">— CARTA DIGITAL —</span>
              <span class="page-counter">{{ pi + 1 }} / {{ carta.length }} · {{ page.titulo }}</span>
            </div>
            <div class="menu-body">
              <div v-for="(sec, si) in page.secciones" :key="si" class="section">
                <div class="section-header">
                  <span>{{ sec.emoji }} {{ sec.titulo }}<em v-if="sec.nota"> — {{ sec.nota }}</em></span>
                </div>
                <div v-for="(item, ii) in sec.items" :key="ii" class="item">
                  <div class="item-info">
                    <div class="item-name">{{ item.nombre }}</div>
                    <div v-if="item.desc" class="item-desc">{{ item.desc }}</div>
                  </div>
                  <!-- Multi-price columns -->
                  <div v-if="sec.columnas" class="price-table">
                    <div v-for="(col, ci) in sec.columnas" :key="ci" class="price-col">
                      <div class="price-col-lbl">{{ col }}</div>
                      <div class="price-col-val">{{ item.precios?.[ci] ?? '$0' }}</div>
                    </div>
                  </div>
                  <!-- Single price -->
                  <div v-else class="item-price">{{ item.precio ?? '$0' }}</div>
                </div>
              </div>
            </div>
            <div class="right-footer">
              <p>★ Los precios con $ 0 serán actualizados pronto ★</p>
            </div>
          </div>
        </div>
      </template>
    </div>

    <!-- Nav dots -->
    <div class="nav-dots">
      <div
        v-for="(_, i) in carta"
        :key="i"
        class="dot"
        :class="{ active: i === current }"
        @click="goTo(i)"
      />
    </div>

    <!-- Swipe hint (auto-fades via CSS) -->
    <div class="swipe-hint">← deslizá para ver más →</div>

    <!-- Admin dot — subtle gold bullet, bottom-right -->
    <button class="admin-dot" @click="goAdmin" aria-label="Admin" />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { useRouter } from 'vue-router'
import logoFile from '@/assets/logo.png'
import { supabase } from '@/services/supabase'
import { useBrandStore } from '@/stores/brand.store'
import { dbRowsToMenuPaginas } from '@/utils/menuMapper'
import type { MenuPagina, MenuSeccionRow, MenuItemRow } from '@/types/domain'

const router = useRouter()
const brand  = useBrandStore()

const logoSrc = logoFile

// Cache key basado en el dominio de la marca (neutral entre clientes)
const CACHE_KEY = computed(() => `carta_${brand.config.emailDomain}`)

// ── CARTA DATA ─────────────────────────────────────────────────────────────
function getCachedMenu(): MenuPagina[] {
  try {
    // Intenta con la clave nueva (basada en la marca)
    const key = `carta_${brand.config.emailDomain}`
    const s = localStorage.getItem(key) ?? localStorage.getItem('lescanos_carta')
    if (s) return JSON.parse(s)
  } catch {}
  const w = window as unknown as Record<string, unknown>
  if (w.DEFAULT_CARTA) return JSON.parse(JSON.stringify(w.DEFAULT_CARTA)) as MenuPagina[]
  return []
}

const carta = ref<MenuPagina[]>(getCachedMenu())

async function loadMenuFromDB() {
  const [{ data: secciones }, { data: items }] = await Promise.all([
    supabase.from('menu_secciones').select('*').order('pagina').order('seccion_orden'),
    supabase.from('menu_items').select('*').order('seccion_id').order('item_orden'),
  ])
  if (!secciones || !items) return
  const paginas = dbRowsToMenuPaginas(secciones as MenuSeccionRow[], items as MenuItemRow[])
  if (paginas.length > 0) {
    carta.value = paginas
    localStorage.setItem(CACHE_KEY.value, JSON.stringify(paginas))
  }
}

// ── CAROUSEL ───────────────────────────────────────────────────────────────
const carouselEl = ref<HTMLElement | null>(null)
const current = ref(0)

function slideW() { return window.innerWidth }

function goTo(index: number) {
  const total = carta.value.length
  current.value = Math.max(0, Math.min(total - 1, index))
  carouselEl.value?.scrollTo({ left: current.value * slideW(), behavior: 'smooth' })
}

function onScroll() {
  if (!carouselEl.value) return
  const idx = Math.round(carouselEl.value.scrollLeft / slideW())
  if (idx !== current.value) current.value = idx
}

function onKeyDown(e: KeyboardEvent) {
  if (e.key === 'ArrowRight') goTo(current.value + 1)
  if (e.key === 'ArrowLeft') goTo(current.value - 1)
}

onMounted(() => {
  document.addEventListener('keydown', onKeyDown)
  loadMenuFromDB()
})

onUnmounted(() => {
  document.removeEventListener('keydown', onKeyDown)
})

// ── ADMIN ──────────────────────────────────────────────────────────────────
function goAdmin() {
  router.push('/login')
}
</script>

<style scoped>
/* CSS custom properties from the global palette */
:root {
  --gold: #C9A84C;
  --dark: #111111;
  --dark2: #1C1C1C;
  --cream: #F5F0E8;
  --cream2: #EDE8DC;
  --gray: #888888;
  --text: #1A1A1A;
}

.carta-root {
  position: fixed;
  inset: 0;
  background: #111;
  overflow: hidden;
}

/* ── CAROUSEL ── */
.carousel {
  display: flex;
  width: 100%;
  height: 100vh;
  overflow-x: scroll;
  scroll-snap-type: x mandatory;
  scrollbar-width: none;
}
.carousel::-webkit-scrollbar { display: none; }

.slide {
  width: 100vw;
  min-width: 0;
  height: 100vh;
  display: flex;
  overflow: hidden;
  scroll-snap-align: start;
  flex-shrink: 0;
}

/* ── LEFT PANEL ── */
.panel-left {
  width: 36%;
  min-width: 36%;
  height: 100%;
  background: #111;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 1.2rem .8rem;
  position: relative;
  flex-shrink: 0;
}
.panel-left::after {
  content: '';
  position: absolute;
  right: 0; top: 0;
  width: 3px; height: 100%;
  background: #C9A84C;
}

.brand-name {
  font-family: 'Playfair Display', serif;
  font-size: clamp(1rem, 3.8vw, 1.7rem);
  font-weight: 900;
  color: #C9A84C;
  letter-spacing: .05em;
  text-align: center;
  line-height: 1;
}
.brand-sub {
  font-size: clamp(.5rem, 1.7vw, .62rem);
  color: #888;
  letter-spacing: .3em;
  margin-top: .3rem;
  text-align: center;
}
.gold-line {
  width: 70%;
  height: 1px;
  background: #C9A84C;
  margin: .55rem auto;
  opacity: .8;
}
.logo-img {
  width: clamp(70px, 21vw, 150px);
  height: auto;
  display: block;
  margin: 0 auto;
}
.contact-title {
  font-size: clamp(.52rem, 1.4vw, .58rem);
  color: #C9A84C;
  letter-spacing: .25em;
  font-weight: 700;
  margin-top: .6rem;
  text-align: center;
}
.contact-list {
  list-style: none;
  margin-top: .35rem;
  width: 100%;
}
.contact-list li {
  font-size: clamp(.55rem, 1.5vw, .6rem);
  color: #BBB;
  text-align: center;
  padding: .16rem 0;
  line-height: 1.3;
}

/* ── RIGHT PANEL ── */
.panel-right {
  flex: 1;
  min-width: 0;
  height: 100%;
  background: #F5F0E8;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
.right-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: .5rem .9rem .35rem;
  border-bottom: 1px solid rgba(201,168,76,.25);
}
.carta-label {
  font-size: clamp(.55rem, 1.5vw, .6rem);
  color: #C9A84C;
  letter-spacing: .18em;
  font-style: italic;
}
.page-counter {
  font-size: clamp(.52rem, 1.4vw, .58rem);
  color: #888;
  font-style: italic;
  white-space: nowrap;
}
.menu-body {
  flex: 1;
  min-width: 0;
  overflow-y: auto;
  padding: 0 .9rem .7rem;
  -webkit-overflow-scrolling: touch;
}
.menu-body::-webkit-scrollbar { display: none; }

.section { margin-top: .65rem; }
.section-header {
  background: #111;
  padding: .32rem .6rem;
  border-radius: 3px;
  margin-bottom: .4rem;
  display: flex;
  align-items: center;
  gap: .35rem;
  overflow: hidden;
}
.section-header span {
  font-weight: 700;
  font-size: clamp(.62rem, 1.9vw, .78rem);
  color: #C9A84C;
  letter-spacing: .07em;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
.section-header em {
  font-weight: 300;
  font-size: .85em;
  color: #aaa;
}

.item {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  padding: .32rem .08rem;
  border-bottom: .5px solid rgba(0,0,0,.08);
  gap: .45rem;
}
.item:last-child { border-bottom: none; }
.item-info { flex: 1; min-width: 0; }
.item-name {
  font-size: clamp(.72rem, 2vw, .82rem);
  font-weight: 700;
  color: #1A1A1A;
  line-height: 1.2;
}
.item-desc {
  font-size: clamp(.60rem, 1.5vw, .62rem);
  color: #888;
  font-style: italic;
  margin-top: .08rem;
  line-height: 1.3;
}
.item-price {
  font-family: 'Playfair Display', serif;
  font-size: clamp(.75rem, 2.1vw, .86rem);
  font-weight: 700;
  color: #C9A84C;
  white-space: nowrap;
  flex-shrink: 0;
  padding-top: .04rem;
}

.price-table {
  display: flex;
  gap: .3rem;
  flex-shrink: 0;
  align-items: flex-end;
}
.price-col {
  display: flex;
  flex-direction: column;
  align-items: center;
  min-width: 42px;
}
.price-col-lbl {
  font-size: clamp(.36rem, .95vw, .42rem);
  color: #888;
  white-space: nowrap;
  line-height: 1.2;
  text-align: center;
}
.price-col-val {
  font-family: 'Playfair Display', serif;
  font-size: clamp(.6rem, 1.65vw, .72rem);
  color: #C9A84C;
  font-weight: 700;
  white-space: nowrap;
  text-align: center;
}

.right-footer {
  padding: .35rem .9rem;
  border-top: 1px solid rgba(201,168,76,.3);
  text-align: center;
}
.right-footer p {
  font-size: clamp(.5rem, 1.2vw, .52rem);
  color: #888;
  font-style: italic;
}

/* ── PROMO SLIDE ── */
.slide-promo {
  background: radial-gradient(ellipse at 40% 30%, #1a1500 0%, #080808 65%);
  display: flex;
  flex-direction: column;
  align-items: center;
  overflow: hidden;
}
.promo-inner {
  width: 100%;
  max-width: 520px;
  height: 100%;
  display: flex;
  flex-direction: column;
  padding: 0 1.5rem;
}
.promo-head {
  text-align: center;
  padding: 1.4rem 0 .9rem;
  border-bottom: 1px solid rgba(201,168,76,.3);
  flex-shrink: 0;
}
.promo-brand {
  font-family: 'Playfair Display', serif;
  font-size: clamp(.6rem, 1.8vw, .75rem);
  color: rgba(201,168,76,.55);
  letter-spacing: .35em;
  margin-bottom: .25rem;
}
.promo-big-title {
  font-family: 'Playfair Display', serif;
  font-size: clamp(2.6rem, 11vw, 4.2rem);
  font-weight: 900;
  color: #C9A84C;
  letter-spacing: .12em;
  line-height: 1;
}
.promo-period {
  font-size: clamp(.55rem, 1.5vw, .68rem);
  color: #888;
  letter-spacing: .18em;
  margin-top: .3rem;
  font-style: italic;
}
.promo-list {
  flex: 1;
  overflow-y: auto;
  padding: .9rem 0;
  display: flex;
  flex-direction: column;
  gap: .7rem;
  -webkit-overflow-scrolling: touch;
}
.promo-list::-webkit-scrollbar { display: none; }
.promo-card {
  border: 1px solid rgba(201,168,76,.22);
  border-radius: 10px;
  padding: 1rem 1.2rem;
  text-align: center;
  background: rgba(201,168,76,.03);
  position: relative;
  overflow: hidden;
}
.promo-card::before {
  content: '';
  position: absolute;
  top: 0;
  left: 50%;
  transform: translateX(-50%);
  width: 50px;
  height: 2px;
  background: #C9A84C;
  opacity: .5;
  border-radius: 1px;
}
.promo-card-name {
  font-family: 'Playfair Display', serif;
  font-size: clamp(.85rem, 3.2vw, 1.05rem);
  color: #C9A84C;
  letter-spacing: .06em;
  text-transform: uppercase;
  line-height: 1.3;
}
.promo-card-price {
  font-family: 'Playfair Display', serif;
  font-size: clamp(1.7rem, 6.5vw, 2.3rem);
  font-weight: 900;
  color: #C9A84C;
  margin-top: .3rem;
  line-height: 1;
}
.promo-efectivo {
  text-align: center;
  padding: .65rem 0;
  font-size: clamp(.6rem, 1.8vw, .75rem);
  color: rgba(201,168,76,.65);
  letter-spacing: .2em;
  border-top: 1px solid rgba(201,168,76,.2);
  flex-shrink: 0;
  font-style: italic;
}

/* ── NAV DOTS ── */
.nav-dots {
  position: fixed;
  bottom: .9rem;
  left: 50%;
  transform: translateX(-50%);
  display: flex;
  gap: 6px;
  z-index: 10;
}
.dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: rgba(201,168,76,.35);
  transition: all .3s ease;
  cursor: pointer;
}
.dot.active {
  background: #C9A84C;
  width: 18px;
  border-radius: 3px;
}

/* ── SWIPE HINT ── */
.swipe-hint {
  position: fixed;
  bottom: 2.4rem;
  left: 50%;
  transform: translateX(-50%);
  font-size: .55rem;
  color: rgba(201,168,76,.5);
  letter-spacing: .1em;
  z-index: 10;
  pointer-events: none;
  animation: fadeHint 3.5s ease forwards;
}
@keyframes fadeHint {
  0%   { opacity: 1 }
  70%  { opacity: 1 }
  100% { opacity: 0 }
}

/* ── ADMIN DOT ── */
.admin-dot {
  position: fixed;
  bottom: .7rem;
  right: .8rem;
  width: 10px;
  height: 10px;
  border-radius: 50%;
  background: rgba(201,168,76,.3);
  border: none;
  cursor: pointer;
  z-index: 20;
  transition: background .3s;
  padding: 0;
}
.admin-dot:hover,
.admin-dot:active {
  background: rgba(201,168,76,.7);
}

/* ── MOBILE ── */
@media (max-width: 480px) {
  .panel-left {
    width: 28%;
    min-width: 28%;
    padding: .8rem .5rem;
  }
  .logo-img {
    width: clamp(50px, 18vw, 90px);
  }
  .menu-body {
    padding: 0 .7rem .5rem;
  }
}
</style>
