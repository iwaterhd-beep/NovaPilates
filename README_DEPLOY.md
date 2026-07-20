# NŌVA PILATES STUDIO — Deploy y operación

App estática (HTML/CSS/JS) + Supabase. Hosting recomendado: **Vercel**.

## 1) Branding
Isotipo: `assets/branding/logo-isotipo.svg` (cabecera, favicon, pie).
Logo principal: `assets/branding/logo-nova-main.PNG`.
Vídeo hero: `assets/video/nova-hero.mp4` (usa `preload="metadata"` + `poster`).
Logos PNG optimizados en `assets/branding/` (también hay SVG `logo-isotipo.svg` para UI ligera).

> `home.css` y `styles.css` existen pero **no se usan** en las páginas actuales (landing = `zen.css`, app = `portal.css`).

## 2) Variables / claves Supabase

Este proyecto **no usa build step**: la URL y la clave **anon (pública)** viven en `supabase.js`.

- `SUPABASE_URL` → ya en `supabase.js`
- `SUPABASE_ANON_KEY` → JWT anon o publishable; **nunca** pongas `service_role` en el front

En Vercel puedes documentar las mismas claves como Environment Variables por rotación, pero el sitio las lee del JS hasta que añadas un build que las inyecte.

## 3) Auth (imprescindible en producción)

En Supabase → **Authentication → URL Configuration**:

- **Site URL:** `https://nova-pilates.vercel.app`
- **Redirect URLs:**  
  - `https://nova-pilates.vercel.app/**`  
  - `http://localhost:8080/**` (desarrollo)

Recuperación de contraseña: el enlace debe abrir `/login.html?reset=true` (flujo implementado en `login.html`).

## 4) Base de datos — orden de scripts SQL

Proyecto vacío:

1. `supabase_full_setup.sql` (tablas, RLS, RPCs base, seeds)
2. `supabase_patch_lista_espera.sql` (RPCs JSONB + lista de espera)
3. `supabase_patch_lista_espera_notify.sql` (notificación al liberar plaza)
4. Patches según features que uses:
   - `supabase_patch_margen_reservas.sql`
   - `supabase_patch_asistencia_compatible.sql`
   - `supabase_patch_admin_crear_usuarios.sql`
   - `supabase_patch_admin_actualizar_password.sql`
   - `supabase_fix_gen_salt_admin_usuario.sql` (si falla `gen_salt`)
   - `supabase_patch_tpv_apellidos_y_tienda.sql`
   - `supabase_patch_caja_apertura_cierre.sql`
   - `supabase_patch_anular_transaccion_tpv.sql`
   - `supabase_patch_tpv_cobrar_ticket.sql` (cobro TPV atómico)
   - `supabase_patch_tipos_bono_web.sql` (planes en web + casilla visible_web)
   - `supabase_patch_eliminar_cliente.sql`
   - `supabase_patch_perfiles_*.sql` (si faltan columnas)

Opcional demo: `supabase_seed_demo.sql` (requiere usuarios Auth previos).

Ejecutar en: Supabase → **SQL Editor**.

## 5) Checklist RLS (seguridad)

Confirma en el dashboard que:

| Tabla | Comportamiento esperado |
|-------|-------------------------|
| `perfiles` | Usuario ve/edita el suyo; staff/admin más amplio |
| `reservas` | Cliente solo las suyas; altas/bajas sensibles vía RPC |
| `bonos_activos` | Cliente lectura propia; escritura staff |
| `clases` / catálogos | Lectura autenticada; escritura staff |
| `notificaciones` | Ver propias (+ generales); insert staff/RPC |
| RPCs | `crear_reserva_segura`, `cancelar_reserva_segura`, etc. como `SECURITY DEFINER` |

Revisa Advisors → Security (revocar `EXECUTE` a `anon` en RPCs sensibles si el linter lo marca).

## 6) GitHub + Vercel

```bash
git remote add origin https://github.com/TU_USUARIO/NovaPilates.git
git branch -M main
git push -u origin main
```

1. [vercel.com/new](https://vercel.com/new) → importa el repo  
2. Framework: **Other**  
3. Deploy  

URL de producción típica: `https://nova-pilates.vercel.app`  
No uses URLs de deploy con hash (`…-xxxx-….vercel.app`) si están protección de Vercel Login: usa el dominio de producción.

`vercel.json` incluye rewrites (`/login`, `/staff`, legales, etc.) y `Cache-Control` en `supabase.js` / login.

## 7) Legal / cookies

Páginas: `/aviso-legal.html`, `/privacidad.html`, `/cookies.html`  
Sustituye los placeholders `[RAZÓN SOCIAL]`, `[CIF/NIF]`, etc. antes de publicar.  
Banner de cookies: `js/cookies-consent.js`.

## 8) SEO

- Meta OG/Twitter en páginas públicas y app  
- `sitemap.xml`, `robots.txt`  
- `LocalBusiness` JSON-LD en `index.html` (completa teléfono/dirección)

## 9) Prueba rápida post-deploy

1. Abrir `/login.html` → login admin  
2. Reservar / cancelar en calendario  
3. Lista de espera + notificación al liberar plaza  
4. Recuperar contraseña (email + pantalla nueva contraseña)  
5. Banner de cookies y enlaces legales en el footer
