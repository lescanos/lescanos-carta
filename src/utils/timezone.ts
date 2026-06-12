// America/Argentina/Buenos_Aires — siempre UTC-3, sin DST

const TZ = 'America/Argentina/Buenos_Aires'

/** Fecha de hoy en BsAs como string YYYY-MM-DD */
export function todayBsAs(): string {
  return new Date().toLocaleDateString('en-CA', { timeZone: TZ })
}

/** Hora actual en BsAs como { hh, mm } */
export function timeBsAs(): { hh: string; mm: string } {
  const parts = new Intl.DateTimeFormat('es-AR', {
    timeZone: TZ,
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).formatToParts(new Date())
  const get = (type: string) => (parts.find(p => p.type === type)?.value ?? '00').padStart(2, '0')
  return { hh: get('hour'), mm: get('minute') }
}

/** Hora:Minuto:Segundo en BsAs como string HH:MM:SS */
export function clockBsAs(): string {
  return new Date().toLocaleTimeString('es-AR', {
    timeZone: TZ,
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  })
}

/** Inicio del día en BsAs como ISO UTC (medianoche BsAs = 03:00 UTC) */
export function dayStartUTC(dateStr: string): string {
  return `${dateStr}T03:00:00.000Z`
}

/** Fin del día en BsAs como ISO UTC */
export function dayEndUTC(dateStr: string): string {
  const [y, m, d] = dateStr.split('-').map(Number)
  return new Date(Date.UTC(y, m - 1, d + 1, 2, 59, 59, 999)).toISOString()
}

/** Formatea un ISO string a HH:MM en BsAs */
export function formatTimeBsAs(iso: string): string {
  return new Date(iso).toLocaleTimeString('es-AR', {
    timeZone: TZ,
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  })
}
