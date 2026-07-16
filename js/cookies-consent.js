(function () {
  const KEY = 'nova_cookie_consent';
  if (localStorage.getItem(KEY)) return;

  const bar = document.createElement('div');
  bar.id = 'nova-cookie-banner';
  bar.setAttribute('role', 'dialog');
  bar.setAttribute('aria-label', 'Consentimiento de cookies');
  bar.innerHTML = `
    <div class="nova-cookie-inner">
      <p>
        Usamos cookies esenciales para el inicio de sesión y el funcionamiento de la app.
        Consulta la <a href="/cookies.html">política de cookies</a>.
      </p>
      <div class="nova-cookie-actions">
        <button type="button" class="nova-cookie-btn nova-cookie-btn--ghost" data-choice="essential">Solo esenciales</button>
        <button type="button" class="nova-cookie-btn" data-choice="all">Aceptar</button>
      </div>
    </div>
  `;
  document.addEventListener('DOMContentLoaded', () => {
    document.body.appendChild(bar);
    bar.querySelectorAll('[data-choice]').forEach((btn) => {
      btn.addEventListener('click', () => {
        localStorage.setItem(KEY, btn.getAttribute('data-choice'));
        bar.remove();
      });
    });
  });
})();
