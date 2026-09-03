import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SITE_URL = "https://nova-pilates.vercel.app";
const LOGO_URL = `${SITE_URL}/assets/branding/logo-nova-main.PNG`;
const STUDIO_IMG_URL = `${SITE_URL}/assets/branding/logo-nova-grande.png`;
const LOGIN_URL = `${SITE_URL}/login.html`;
const MAPS_URL =
  "https://www.google.com/maps/search/?api=1&query=N%C5%8CVA+Pilates+Sevilla";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function buildWelcomeHtml(nombre: string): string {
  const safeName = escapeHtml(nombre);
  const instagram =
    Deno.env.get("EMAIL_INSTAGRAM_URL") || "https://www.instagram.com/";
  const whatsapp = Deno.env.get("EMAIL_WHATSAPP_URL") || "https://wa.me/";
  const maps = Deno.env.get("EMAIL_MAPS_URL") || MAPS_URL;
  const studioImg = Deno.env.get("EMAIL_STUDIO_IMAGE_URL") || STUDIO_IMG_URL;

  return `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Bienvenido/a a NŌVA</title>
</head>
<body style="margin:0;padding:0;background-color:#e8e2d8;-webkit-text-size-adjust:100%;">
  <div style="display:none;max-height:0;overflow:hidden;mso-hide:all;">
    Tu cuenta en NŌVA ya está lista. Te damos la bienvenida.
  </div>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#e8e2d8;">
    <tr>
      <td align="center" style="padding:32px 16px;">
        <table role="presentation" width="560" cellpadding="0" cellspacing="0" border="0" style="max-width:560px;width:100%;background-color:#f7f3ec;">
          <tr>
            <td align="center" style="padding:40px 32px 16px;">
              <img src="${LOGO_URL}" alt="NŌVA" width="120" style="display:block;border:0;height:auto;max-width:120px;" />
            </td>
          </tr>
          <tr>
            <td align="center" style="padding:8px 32px 0;font-family:Georgia,'Times New Roman',Times,serif;font-size:32px;line-height:1.2;color:#1a1a1a;letter-spacing:0.02em;">
              Bienvenido/a
            </td>
          </tr>
          <tr>
            <td align="center" style="padding:20px 32px 8px;font-family:Georgia,'Times New Roman',Times,serif;font-size:18px;line-height:1.4;color:#2c2c2c;">
              Hola ${safeName},
            </td>
          </tr>
          <tr>
            <td align="center" style="padding:0 40px 28px;font-family:Arial,Helvetica,sans-serif;font-size:15px;line-height:1.6;color:#4a453f;">
              Hemos creado tu cuenta en NŌVA. Ya puedes reservar clases, consultar tus bonos y gestionar tu perfil desde el portal.
            </td>
          </tr>
          <tr>
            <td style="padding:0;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#ebe4d8;">
                <tr>
                  <td style="padding:28px 36px;">
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td style="padding:0 0 14px;font-family:Arial,Helvetica,sans-serif;font-size:14px;line-height:1.5;color:#2c2c2c;">
                          <span style="color:#8a7355;">●</span>&nbsp;&nbsp;Tu cuenta ya está activa
                        </td>
                      </tr>
                      <tr>
                        <td style="padding:0 0 14px;font-family:Arial,Helvetica,sans-serif;font-size:14px;line-height:1.5;color:#2c2c2c;">
                          <span style="color:#8a7355;">●</span>&nbsp;&nbsp;Reserva clases cuando quieras
                        </td>
                      </tr>
                      <tr>
                        <td style="padding:0 0 14px;font-family:Arial,Helvetica,sans-serif;font-size:14px;line-height:1.5;color:#2c2c2c;">
                          <span style="color:#8a7355;">●</span>&nbsp;&nbsp;Accede con tu email en el portal
                        </td>
                      </tr>
                      <tr>
                        <td style="padding:0;font-family:Arial,Helvetica,sans-serif;font-size:14px;line-height:1.5;color:#2c2c2c;">
                          <span style="color:#8a7355;">●</span>&nbsp;&nbsp;Si necesitas ayuda, escríbenos
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
          <tr>
            <td align="center" style="padding:36px 32px 12px;font-family:Georgia,'Times New Roman',Times,serif;font-size:22px;line-height:1.3;color:#1a1a1a;">
              Nuestra filosofía
            </td>
          </tr>
          <tr>
            <td align="center" style="padding:0 40px 20px;font-family:Arial,Helvetica,sans-serif;font-size:14px;line-height:1.65;color:#4a453f;">
              Movimiento consciente, ritmo propio y un espacio donde cuidarte sin prisas. En NŌVA cada clase es una invitación a estar presente.
            </td>
          </tr>
          <tr>
            <td align="center" style="padding:0 24px 32px;">
              <img src="${escapeHtml(studioImg)}" alt="NŌVA Pilates Studio" width="320" style="display:block;border:0;height:auto;max-width:100%;margin:0 auto;" />
            </td>
          </tr>
          <tr>
            <td align="center" style="padding:8px 32px 40px;font-family:Georgia,'Times New Roman',Times,serif;font-size:16px;line-height:1.6;color:#2c2c2c;">
              Con cariño,<br />
              El equipo de NŌVA
            </td>
          </tr>
          <tr>
            <td style="padding:0;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#ebe4d8;">
                <tr>
                  <td align="center" style="padding:28px 24px 8px;font-family:Georgia,'Times New Roman',Times,serif;font-size:18px;color:#1a1a1a;letter-spacing:0.08em;">
                    NŌVA
                  </td>
                </tr>
                <tr>
                  <td align="center" style="padding:0 24px 16px;font-family:Arial,Helvetica,sans-serif;font-size:12px;line-height:1.5;color:#6b645c;">
                    Pilates · Movimiento · Bienestar
                  </td>
                </tr>
                <tr>
                  <td align="center" style="padding:0 24px 28px;font-family:Arial,Helvetica,sans-serif;font-size:13px;">
                    <a href="${escapeHtml(instagram)}" style="color:#4a453f;text-decoration:none;margin:0 10px;">Instagram</a>
                    <span style="color:#c4b8a8;">·</span>
                    <a href="${escapeHtml(whatsapp)}" style="color:#4a453f;text-decoration:none;margin:0 10px;">WhatsApp</a>
                    <span style="color:#c4b8a8;">·</span>
                    <a href="${escapeHtml(maps)}" style="color:#4a453f;text-decoration:none;margin:0 10px;">Ubicación</a>
                  </td>
                </tr>
                <tr>
                  <td align="center" style="padding:0 24px 24px;font-family:Arial,Helvetica,sans-serif;font-size:11px;color:#9a9188;">
                    <a href="${LOGIN_URL}" style="color:#8a7355;text-decoration:underline;">Entrar al portal</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return json(405, { error: "Method not allowed" });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json(401, { error: "Falta Authorization" });
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const supabaseAnonKey = Deno.env.get("SUPABASE_ANON_KEY");
    if (!supabaseUrl || !supabaseAnonKey) {
      return json(500, { error: "Faltan variables SUPABASE_URL / ANON_KEY" });
    }

    const supabase = createClient(supabaseUrl, supabaseAnonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const {
      data: { user },
      error: userErr,
    } = await supabase.auth.getUser();
    if (userErr || !user) {
      return json(401, { error: "Sesión no válida" });
    }

    const { data: perfil, error: perfilErr } = await supabase
      .from("perfiles")
      .select("rol")
      .eq("id", user.id)
      .maybeSingle();

    if (perfilErr || !perfil || !["admin", "empleado"].includes(perfil.rol)) {
      return json(403, { error: "Solo staff puede enviar bienvenida" });
    }

    const body = await req.json().catch(() => null);
    const email = String(body?.email || "")
      .trim()
      .toLowerCase();
    const nombre = String(body?.nombre || "").trim() || "cliente";

    if (!email || !email.includes("@")) {
      return json(400, { error: "Email inválido" });
    }

    const resendKey = Deno.env.get("RESEND_API_KEY");
    const resendFrom =
      Deno.env.get("RESEND_FROM") || "NŌVA Pilates <onboarding@resend.dev>";

    if (!resendKey) {
      return json(500, {
        error:
          "Falta RESEND_API_KEY en secrets de la Edge Function. Ver README_DEPLOY.md",
      });
    }

    const html = buildWelcomeHtml(nombre);
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: resendFrom,
        to: [email],
        subject: "Bienvenido/a a NŌVA",
        html,
      }),
    });

    const resendBody = await res.json().catch(() => ({}));
    if (!res.ok) {
      console.error("Resend error", res.status, resendBody);
      return json(502, {
        error: "No se pudo enviar el email",
        detail: resendBody,
      });
    }

    return json(200, { ok: true, id: resendBody?.id ?? null });
  } catch (err) {
    console.error(err);
    return json(500, {
      error: err instanceof Error ? err.message : "Error interno",
    });
  }
});
