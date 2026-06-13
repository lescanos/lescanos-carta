// ── ROLES ──────────────────────────────────────────────────────────────────
export type Rol = 'dueno' | 'moza' | 'caja' | 'cocina'

// ── USUARIOS ───────────────────────────────────────────────────────────────
export interface Perfil {
  id: string
  nombre: string
  login_key: string
  rol: Rol
  emoji: string
  activo: boolean
}

export interface CurrentUser {
  id: string
  nombre: string
  rol: Rol
}

// ── SESIONES ───────────────────────────────────────────────────────────────
export type EstadoSesion = 'abierta' | 'cerrada'
export type TipoSesion = 'mesa' | 'envio' | 'llevar'

export interface Sesion {
  id: string
  mesa: string
  estado: EstadoSesion
  tipo: TipoSesion
  cubiertos: number | null
  moza_id: string | null
  moza_nombre: string | null
  cliente_nombre: string | null
  cliente_telefono: string | null
  cliente_direccion: string | null
  cliente_referencia: string | null
  metodo_pago: string | null
  created_at: string
  closed_at: string | null
}

// ── PEDIDOS ────────────────────────────────────────────────────────────────
export type EstadoPedido = 'pendiente' | 'listo'
export type TipoPedido = 'pedido' | 'cambio' | 'cancelacion'

export interface Pedido {
  id: string
  sesion_id: string
  estado: EstadoPedido
  tipo: TipoPedido
  listo_at: string | null
  created_at: string
  sesiones?: Pick<Sesion, 'mesa'>
  pedido_items?: PedidoItem[]
}

// ── ITEMS ──────────────────────────────────────────────────────────────────
export interface PedidoItem {
  id: string
  pedido_id: string
  sesion_id: string
  nombre: string
  precio: string
  qty: number
  nota: string | null
  seccion: string | null
  created_at: string
}

// ── PAGOS ──────────────────────────────────────────────────────────────────
export type MetodoPago = 'efectivo' | 'debito' | 'credito' | 'transferencia' | 'mercadopago' | 'pedidosya'

export interface Pago {
  id: string
  sesion_id: string
  metodo: MetodoPago
  monto: number
  created_at: string
}

// ── CIERRES ────────────────────────────────────────────────────────────────
export interface Cierre {
  id: string
  fecha: string
  total: number
  efectivo: number
  debito: number
  credito: number
  transferencia: number
  mercadopago: number
  pedidosya: number
  notas: string | null
  created_at: string
}

// ── CARRITO (estado local) ─────────────────────────────────────────────────
export interface CartItem {
  id: string          // clave local única (p0s1i2, p0s1i2-c0, promo-0-3, etc.)
  nombre: string
  precio: string
  qty: number
  nota?: string
  pagina?: string
  seccion?: string
}

// ── MENÚ (filas de la base de datos) ──────────────────────────────────────
export interface MenuSeccionRow {
  id: string
  pagina: number
  pagina_titulo: string
  pagina_tipo: string
  pagina_subtitulo: string | null
  seccion_orden: number
  emoji: string | null
  titulo: string
  nota: string | null
  columnas: string[] | null
}

export interface MenuItemRow {
  id: string
  seccion_id: string
  item_orden: number
  nombre: string
  descripcion: string | null
  precios: string[]
}

// ── MENÚ (estructura para CartaPage / localStorage) ───────────────────────
export interface MenuItem {
  nombre: string
  desc?: string
  precio?: string
  precios?: string[]
}

export interface MenuSeccion {
  emoji?: string
  titulo: string
  nota?: string
  columnas?: string[]
  items: MenuItem[]
}

export interface MenuPagina {
  pagina: string
  titulo: string
  tipo?: 'promos'
  subtitulo?: string
  secciones?: MenuSeccion[]
  items?: MenuItem[]
}
