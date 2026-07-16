// NŌVA PILATES STUDIO - cliente Supabase
const SUPABASE_URL = 'https://atdhljdogjhsoyraekwz.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImF0ZGhsamRvZ2poc295cmFla3d6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQyMTg3MzcsImV4cCI6MjA5OTc5NDczN30.g7poBIKyTcMPvcGvRUDS169uktE-YWm9Y_F3Pc7evqs';
const novaSupabase = supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
  auth: {
    persistSession: true,
    autoRefreshToken: true,
    detectSessionInUrl: true,
    storage: window.localStorage
  }
});

function goLogin() {
  window.location.replace('/login.html');
}

async function getSession() {
  const { data: { session } } = await novaSupabase.auth.getSession();
  return session;
}

async function getCurrentUser() {
  const session = await getSession();
  return session?.user ?? null;
}

async function getUserProfile(userId) {
  const { data, error } = await novaSupabase
    .from('perfiles')
    .select('*')
    .eq('id', userId)
    .single();
  if (error) throw error;
  return data;
}

async function requireAuth(rolesPermitidos = null) {
  const session = await getSession();
  if (!session) {
    goLogin();
    return null;
  }

  if (!rolesPermitidos) return session.user;

  const profile = await getUserProfile(session.user.id);
  const roles = Array.isArray(rolesPermitidos) ? rolesPermitidos : [rolesPermitidos];
  if (!roles.includes(profile?.rol)) {
    goLogin();
    return null;
  }
  return profile;
}

async function signOut() {
  await novaSupabase.auth.signOut();
  goLogin();
}

async function getBonoActivo(perfilId) {
  const hoy = new Date().toISOString().split('T')[0];
  const { data, error } = await novaSupabase
    .from('bonos_activos')
    .select('id, sesiones_totales, sesiones_usadas, fecha_inicio, fecha_fin, activo, tipo_bono:tipo_bono_id(nombre, ilimitado)')
    .eq('perfil_id', perfilId)
    .eq('activo', true)
    .gte('fecha_fin', hoy)
    .order('fecha_inicio', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) throw error;
  return data;
}

async function crearReservaSegura(claseId) {
  const { data, error } = await novaSupabase.rpc('crear_reserva_segura', { p_clase_id: claseId });
  if (error) throw error;
  return data;
}

async function cancelarReservaSegura(reservaId) {
  const { data, error } = await novaSupabase.rpc('cancelar_reserva_segura', { p_reserva_id: reservaId });
  if (error) throw error;
  return data;
}

async function getReservasUsuario(perfilId) {
  const { data, error } = await novaSupabase
    .from('reservas')
    .select('id, estado, fecha_reserva, fecha_cancelacion, clase_id')
    .eq('perfil_id', perfilId)
    .order('fecha_reserva', { ascending: false });

  if (error) throw error;
  return data ?? [];
}
