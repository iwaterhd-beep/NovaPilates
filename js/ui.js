/** Utilidades UI compartidas: toasts, spinners y errores amigables */

function friendlyError(err) {
  const raw = (err && (err.message || err.error_description || err.msg)) || String(err || '');
  const map = [
    [/invalid login credentials/i, 'Correo o contraseña incorrectos.'],
    [/email not confirmed/i, 'Debes confirmar tu correo antes de entrar.'],
    [/user already registered/i, 'Ya existe una cuenta con ese correo.'],
    [/password/i, 'Revisa la contraseña (mínimo 6 caracteres).'],
    [/jwt|session|auth/i, 'Tu sesión ha caducado. Vuelve a iniciar sesión.'],
    [/network|fetch|failed to fetch/i, 'No hay conexión. Comprueba internet e inténtalo de nuevo.'],
    [/no hay plazas/i, 'No quedan plazas en esta clase.'],
    [/bono activo/i, 'No tienes un bono activo. Pasa por recepción.'],
    [/sesiones disponibles/i, 'No te quedan sesiones en el bono.'],
    [/antelaci[oó]n/i, 'No cumples el margen de antelación configurado.'],
    [/permiso|policy|rls|row level/i, 'No tienes permiso para esta acción.'],
  ];
  for (const [re, msg] of map) {
    if (re.test(raw)) return msg;
  }
  if (!raw || raw.length > 160) return 'Ha ocurrido un error. Inténtalo de nuevo.';
  return raw;
}

function ensureToastHost() {
  let host = document.getElementById('nova-toast-host');
  if (!host) {
    host = document.createElement('div');
    host.id = 'nova-toast-host';
    document.body.appendChild(host);
  }
  return host;
}

function showToast(message, type = 'info', ms = 3500) {
  const host = ensureToastHost();
  const el = document.createElement('div');
  el.className = `nova-toast nova-toast--${type}`;
  el.textContent = message;
  host.appendChild(el);
  requestAnimationFrame(() => el.classList.add('show'));
  setTimeout(() => {
    el.classList.remove('show');
    setTimeout(() => el.remove(), 280);
  }, ms);
}

function showConfirm(message, { confirmLabel = 'Confirmar', cancelLabel = 'Cancelar' } = {}) {
  return new Promise((resolve) => {
    const overlay = document.createElement('div');
    overlay.className = 'nova-confirm-overlay';
    overlay.innerHTML = `
      <div class="nova-confirm" role="dialog" aria-modal="true">
        <p>${message}</p>
        <div class="nova-confirm-actions">
          <button type="button" class="nova-cookie-btn nova-cookie-btn--ghost" data-act="no">${cancelLabel}</button>
          <button type="button" class="nova-cookie-btn" data-act="yes">${confirmLabel}</button>
        </div>
      </div>`;
    document.body.appendChild(overlay);
    overlay.addEventListener('click', (e) => {
      const act = e.target.getAttribute('data-act');
      if (!act) return;
      overlay.remove();
      resolve(act === 'yes');
    });
  });
}

function showPageSpinner(on = true) {
  let el = document.getElementById('nova-page-spinner');
  if (on) {
    if (!el) {
      el = document.createElement('div');
      el.id = 'nova-page-spinner';
      el.innerHTML = '<div class="nova-spinner" aria-label="Cargando"></div>';
      document.body.appendChild(el);
    }
    el.classList.add('show');
  } else if (el) {
    el.classList.remove('show');
  }
}

async function withSpinner(fn) {
  showPageSpinner(true);
  try {
    return await fn();
  } finally {
    showPageSpinner(false);
  }
}
