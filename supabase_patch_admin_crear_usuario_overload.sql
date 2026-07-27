-- Fix: "Could not choose the best candidate function" en admin_crear_usuario
-- Había dos firmas (p_rol rol_usuario y p_rol text). Dejamos solo text.

DROP FUNCTION IF EXISTS public.admin_crear_usuario(TEXT, TEXT, TEXT, public.rol_usuario);

-- La versión canónica queda en supabase_patch_primera_activacion.sql /
-- supabase_patch_admin_crear_usuarios.sql (p_rol TEXT).
