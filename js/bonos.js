function escBonos(str) {
  return String(str ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function renderBonosCatalog() {
  const grid = document.getElementById('plansGrid');
  if (!grid) return;
  grid.innerHTML = NOVA_MEMBERSHIPS.map((p) => {
    const isPriority = !!p.is_priority;
    const n = Number(p.precio || 0);
    const priceFormatted = Number.isInteger(n) ? String(n) : n.toFixed(2).replace('.', ',');
    return `
      <article class="card plan-card ${isPriority ? 'plan-card--priority' : ''}" data-plan-key="${escBonos(p.id)}">
        <div>
          ${isPriority ? '<span class="plan-badge">La más completa</span>' : ''}
          <p class="plan-tag">${escBonos(p.web_tag)}</p>
          <h3 class="plan-title">${escBonos(p.nombre)}</h3>
          <p class="plan-price">${priceFormatted} €<span class="plan-period">${escBonos(p.periodo_label || '/mes')}</span></p>
          <p class="plan-card-desc">${escBonos(p.lema || p.descripcion || '')}</p>
          <ul class="plan-card-highlights">
            ${(p.highlights || []).map(h => `<li>${escBonos(h)}</li>`).join('')}
          </ul>
        </div>
        <button type="button" class="btn ${isPriority ? 'btn-primary' : 'btn-outline'} plan-card-btn" onclick="openStudioInviteModal('${escBonos(p.nombre)}')">
          ${escBonos(p.cta || 'Elegir mi membresía')}
        </button>
      </article>`;
  }).join('');
}

function ensureStudioInviteModal() {
  if (document.getElementById('studioInviteModal')) return;
  const wrap = document.createElement('div');
  wrap.innerHTML = `
    <div class="studio-modal-backdrop" id="studioInviteModalBackdrop" onclick="closeStudioInviteModal()"></div>
    <div class="studio-modal" id="studioInviteModal" role="dialog" aria-modal="true" aria-labelledby="studioInviteTitle" hidden>
      <div class="studio-modal-box">
        <button type="button" class="studio-modal-close" onclick="closeStudioInviteModal()" aria-label="Cerrar">×</button>
        <span class="studio-modal-tag">Te esperamos en NŌVA</span>
        <h2 class="studio-modal-title" id="studioInviteTitle">Comienza tu experiencia</h2>
        <p class="studio-modal-desc" id="studioInviteDesc">
          Para garantizar una experiencia cuidada y personalizada, todos los pagos y activaciones de membresía se realizan directamente en el centro.
        </p>
        <div class="studio-modal-info-box">
          <strong>📍 Estudio NŌVA:</strong> Av. José Rodríguez de la Borbolla Camoyán, 10 · Dos Hermanas, Sevilla<br>
          <strong>Horario de recepción:</strong> Lunes a Viernes de 08:00 a 21:00
        </div>
        <div class="studio-modal-actions">
          <a class="btn btn-primary" id="studioInviteInstagramBtn" href="${NOVA_INSTAGRAM_DM_URL}" target="_blank" rel="noopener noreferrer">
            Escríbenos por Instagram
          </a>
          <button type="button" class="btn btn-outline" onclick="closeStudioInviteModal()">
            Volver a explorar
          </button>
        </div>
      </div>
    </div>`;
  while (wrap.firstChild) document.body.appendChild(wrap.firstChild);
}

window.openStudioInviteModal = function(planName) {
  ensureStudioInviteModal();
  const name = planName || 'tu membresía';
  const title = document.getElementById('studioInviteTitle');
  const desc = document.getElementById('studioInviteDesc');
  const igBtn = document.getElementById('studioInviteInstagramBtn');
  if (title) title.textContent = `Membresía ${name}`;
  if (desc) {
    desc.textContent = `Has seleccionado ${name}. En NŌVA nos gusta conocerte personalmente, mostrarte el espacio y configurar tu acceso en recepción. Todos los pagos se realizan directamente en el centro.`;
  }
  if (igBtn) igBtn.href = NOVA_INSTAGRAM_DM_URL;
  const modal = document.getElementById('studioInviteModal');
  const backdrop = document.getElementById('studioInviteModalBackdrop');
  if (modal && backdrop) {
    modal.hidden = false;
    requestAnimationFrame(() => {
      modal.classList.add('is-open');
      backdrop.classList.add('is-open');
    });
  }
};

window.closeStudioInviteModal = function() {
  const modal = document.getElementById('studioInviteModal');
  const backdrop = document.getElementById('studioInviteModalBackdrop');
  if (!modal) return;
  modal.classList.remove('is-open');
  if (backdrop) backdrop.classList.remove('is-open');
  setTimeout(() => {
    modal.hidden = true;
  }, 250);
};

async function loadBonosSections() {
  const root = document.getElementById('page-root');
  if (!root) return;
  try {
    const res = await fetch('sections/bonos_zen.html');
    if (!res.ok) throw new Error('No se pudo cargar la vista de bonos.');
    root.innerHTML = await res.text();
    renderBonosCatalog();
    document.querySelectorAll('.js-instagram-link').forEach((el) => {
      el.href = NOVA_INSTAGRAM_DM_URL;
    });
    if (typeof initNovaNav === 'function') initNovaNav();
  } catch (err) {
    console.error(err);
  }
}

loadBonosSections();
