import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const admin = createClient(supabaseUrl, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

    // Verify caller is authenticated using their own JWT
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) return json({ error: 'Sin autorización' }, 401)

    const userClient = createClient(
      supabaseUrl,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    )
    const { data: { user }, error: authErr } = await userClient.auth.getUser()
    if (authErr || !user) return json({ error: 'Token inválido' }, 401)

    // Verify caller is dueno (admin client bypasses RLS)
    const { data: perfil } = await admin.from('perfiles').select('rol').eq('id', user.id).single()
    if (perfil?.rol !== 'dueno') return json({
      error: 'Solo el dueño puede gestionar usuarios',
      debug: { jwt_uid: user.id, perfil_rol: perfil?.rol ?? null }
    }, 403)

    const { action, userId, data: payload } = await req.json()

    if (action === 'createUser') {
      const { nombre, login_key, rol, emoji, password } = payload
      const email = `${login_key}@lescanos.local`

      const { data: newUser, error } = await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
      })
      if (error) return json({ error: error.message }, 400)

      const { error: pErr } = await admin.from('perfiles').insert({
        id: newUser.user.id,
        nombre,
        login_key,
        rol,
        emoji: emoji || '🧑',
        activo: true,
      })
      if (pErr) {
        await admin.auth.admin.deleteUser(newUser.user.id)
        return json({ error: pErr.message }, 400)
      }

      return json({ id: newUser.user.id })
    }

    if (action === 'resetPassword') {
      const { password } = payload
      const { error } = await admin.auth.admin.updateUserById(userId, { password })
      if (error) return json({ error: error.message }, 400)
      return json({ ok: true })
    }

    if (action === 'deleteUser') {
      await admin.from('perfiles').delete().eq('id', userId)
      await admin.auth.admin.deleteUser(userId)
      return json({ ok: true })
    }

    return json({ error: 'Acción desconocida' }, 400)
  } catch (err) {
    return json({ error: String(err) }, 500)
  }
})
