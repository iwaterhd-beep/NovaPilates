-- Fix Auth "Database error querying schema"
-- Causa: confirmation_token / recovery_token NULL (GoTrue espera '').
-- Ya aplicado en remoto vía migración; este archivo documenta el arreglo.

UPDATE auth.users
SET
  confirmation_token = COALESCE(confirmation_token, ''),
  recovery_token = COALESCE(recovery_token, ''),
  email_change_token_new = COALESCE(email_change_token_new, ''),
  email_change = COALESCE(email_change, ''),
  phone_change = COALESCE(phone_change, ''),
  phone_change_token = COALESCE(phone_change_token, ''),
  email_change_token_current = COALESCE(email_change_token_current, ''),
  reauthentication_token = COALESCE(reauthentication_token, '')
WHERE confirmation_token IS NULL
   OR recovery_token IS NULL
   OR email_change_token_new IS NULL
   OR email_change IS NULL
   OR phone_change IS NULL
   OR phone_change_token IS NULL
   OR email_change_token_current IS NULL
   OR reauthentication_token IS NULL;

-- Usar siempre la versión de admin_crear_usuario en supabase_patch_primera_activacion.sql
-- (inserta tokens como '').
