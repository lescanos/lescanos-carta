import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { supabase } from '@/services/supabase'

export interface BrandConfig {
  nombre:              string
  subtitulo:           string
  emailDomain:         string
  contactoDireccion:   string
  contactoTelefono:    string
  contactoInstagram:   string
  contactoFacebook:    string
}

const DEFAULTS: BrandConfig = {
  nombre:            'Mi Negocio',
  subtitulo:         'SISTEMA DE GESTIÓN',
  emailDomain:       'negocio.local',
  contactoDireccion: '',
  contactoTelefono:  '',
  contactoInstagram: '',
  contactoFacebook:  '',
}

const KEY_MAP: Record<string, keyof BrandConfig> = {
  brand_nombre:             'nombre',
  brand_subtitulo:          'subtitulo',
  brand_email_domain:       'emailDomain',
  brand_contacto_direccion: 'contactoDireccion',
  brand_contacto_telefono:  'contactoTelefono',
  brand_contacto_instagram: 'contactoInstagram',
  brand_contacto_facebook:  'contactoFacebook',
}

export const useBrandStore = defineStore('brand', () => {
  const config  = ref<BrandConfig>({ ...DEFAULTS })
  const loaded  = ref(false)

  // Cache key neutro — usa el dominio del email para no colisionar entre clientes
  const cacheKey = computed(() => `brand_${config.value.emailDomain}`)

  async function init() {
    // Intenta cargar desde localStorage primero (para render inmediato)
    try {
      const cached = localStorage.getItem('brand_config')
      if (cached) config.value = { ...DEFAULTS, ...JSON.parse(cached) }
    } catch {}

    // Luego carga desde Supabase (anon puede leer config)
    const { data } = await supabase
      .from('config')
      .select('clave, valor')
      .like('clave', 'brand_%')

    if (data && data.length > 0) {
      const next = { ...DEFAULTS }
      for (const row of data) {
        const field = KEY_MAP[row.clave]
        if (field) (next as Record<string, string>)[field] = row.valor
      }
      config.value = next
      try {
        localStorage.setItem('brand_config', JSON.stringify(next))
      } catch {}
    }

    loaded.value = true
  }

  async function update(field: keyof BrandConfig, valor: string) {
    const clave = Object.entries(KEY_MAP).find(([, v]) => v === field)?.[0]
    if (!clave) return

    const { error } = await supabase
      .from('config')
      .upsert({ clave, valor }, { onConflict: 'clave' })

    if (!error) {
      config.value = { ...config.value, [field]: valor }
      try {
        localStorage.setItem('brand_config', JSON.stringify(config.value))
      } catch {}
    }
    return error
  }

  return { config, loaded, cacheKey, init, update }
})
