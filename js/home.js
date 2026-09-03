function escHome(str) {
  return String(str ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function formatPlanPrice(b) {
  const n = Number(b.precio || 0);
  const formatted = Number.isInteger(n) ? String(n) : n.toFixed(2).replace('.', ',');
  return `${formatted} €`;
}

let homePlansByKey = new Map();

function indexHomePlans(plans) {
  homePlansByKey = new Map();
  (plans || []).forEach((p, i) => {
    const key = p.id || `plan-${i}`;
    homePlansByKey.set(key, { ...p, id: key });
  });
}

function renderHomePlans(grid, plans) {
  if (!grid) return;
  indexHomePlans(plans);
  grid.innerHTML = plans
    .map((p) => {
      const isPriority = !!p.is_priority;
      return `
      <article class="card plan-card ${isPriority ? 'plan-card--priority' : ''}" data-plan-key="${escHome(p.id)}">
        <div>
          ${isPriority ? '<span class="plan-badge">La más completa</span>' : ''}
          <p class="plan-tag">${escHome(p.web_tag)}</p>
          <h3 class="plan-title">${escHome(p.nombre)}</h3>
          <p class="plan-price">${escHome(formatPlanPrice(p))}<span class="plan-period">${escHome(p.periodo_label || 'al mes')}</span></p>
          <p class="plan-card-desc">${escHome(p.lema || p.descripcion || '')}</p>
          <ul class="plan-card-highlights">
            ${(p.highlights || []).map(h => `<li>${escHome(h)}</li>`).join('')}
          </ul>
        </div>
        <button type="button" class="btn ${isPriority ? 'btn-primary' : 'btn-outline'} plan-card-btn" onclick="openStudioInviteModal('${escHome(p.nombre)}')">
          ${escHome(p.cta || 'Elegir mi membresía')}
        </button>
      </article>`;
    })
    .join('');
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

/* ── NŌVA RITUAL CARTA ── */
const RITUAL_CARTA_PRODUCTS = [
  {
    id: 'ritual-botella',
    title: 'Botella NŌVA Acero',
    category: 'Accesorios & Hidratación',
    description: 'Botella térmica de acero inoxidable de doble pared. Mantiene tu infusión o agua fría durante toda tu sesión de práctica.',
    price: 28,
    img: '/assets/shop/botella-nova.png'
  },
  {
    id: 'ritual-tote',
    title: 'Tote Bag NŌVA Studio',
    category: 'Accesorios',
    description: 'Bolsa de algodón orgánico reforzado con compartimento interior para toalla, botella y esenciales de entrenamiento.',
    price: 32,
    img: '/assets/shop/tote-studio.png'
  },
  {
    id: 'ritual-camiseta',
    title: 'Camiseta Técnica Suave',
    category: 'Textil & Movimiento',
    description: 'Tejido transpirable con tacto segunda piel, corte ergonómico diseñado para fluir en Reformer, suelo y yoga.',
    price: 35,
    img: '/assets/shop/camiseta-tecnica.png'
  },
  {
    id: 'ritual-bandas',
    title: 'Set de Bandas Elásticas',
    category: 'Movimiento Consciente',
    description: 'Pack de bandas textiles antideslizantes de tres intensidades para complementar tus clases de Barre y Sculpt.',
    price: 22,
    img: '/assets/shop/banda-resistencia.png'
  }
];

function renderHomeRitualCarta(grid) {
  if (!grid) return;
  grid.innerHTML = RITUAL_CARTA_PRODUCTS.map((p) => `
    <article class="shop-card">
      <div class="shop-card-media">
        <img class="shop-card-img" src="${p.img}" alt="${escHome(p.title)}" onerror="this.src='/assets/branding/logo-circulo-nova.png'" loading="lazy" />
      </div>
      <div class="shop-card-body">
        <span class="shop-card-tag">${escHome(p.category)}</span>
        <h3 class="shop-card-title">${escHome(p.title)}</h3>
        <p class="shop-card-price">${p.price} €</p>
        <span class="shop-card-carta-note">Disponible en el estudio</span>
      </div>
    </article>
  `).join('');
}

async function loadPublicPlans() {
  const grid = document.getElementById('plansGrid');
  if (!grid) return;
  renderHomePlans(grid, NOVA_MEMBERSHIPS);
}

async function loadHomeMerch() {
  const grid = document.getElementById('homeShopGrid');
  if (!grid) return;
  renderHomeRitualCarta(grid);
}

function initScrollNav() {
  const nav = document.querySelector('.nav');
  if (!nav) return;
  const onScroll = () => {
    if (window.scrollY > 24) nav.classList.add('is-scrolled');
    else nav.classList.remove('is-scrolled');
  };
  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();
}

function initHeroMotion() {
  const copy = document.querySelector('.hero-copy');
  if (copy) copy.classList.add('is-ready');
}

function initHeroVideo() {
  const video = document.querySelector('.hero-video');
  if (!video) return;
  video.muted = true;
  video.defaultMuted = true;
  video.loop = true;
  video.playsInline = true;
  video.setAttribute('playsinline', '');
  video.setAttribute('webkit-playsinline', '');
  const tryPlay = () => {
    const playPromise = video.play();
    if (playPromise && typeof playPromise.catch === 'function') {
      playPromise.catch(() => {});
    }
  };
  tryPlay();
  video.addEventListener('pause', () => {
    if (document.hidden) return;
    tryPlay();
  });
  video.addEventListener('stalled', tryPlay);
  video.addEventListener('suspend', tryPlay);
  document.addEventListener('visibilitychange', () => {
    if (!document.hidden) tryPlay();
  });
  window.addEventListener('pageshow', tryPlay);
  window.addEventListener('focus', tryPlay);
  document.addEventListener('touchstart', tryPlay, { once: true, passive: true });
  document.addEventListener('click', tryPlay, { once: true });
}

function bindInstagramLinks() {
  document.querySelectorAll('.js-instagram-link').forEach((el) => {
    el.href = NOVA_INSTAGRAM_DM_URL;
  });
}

function initRevealMotion() {
  const root = document.getElementById('page-root');
  if (!root) return;
  const nodes = root.querySelectorAll('.section, .view-card, .plan-card, .shop-card, .process-step');
  nodes.forEach(n => n.classList.add('is-in'));
}

async function loadHomeSections() {
  const root = document.getElementById('page-root');
  if (!root) return;
  try {
    const response = await fetch('sections/home_zen.html');
    if (!response.ok) throw new Error('No se pudo cargar la home.');
    root.innerHTML = await response.text();
    await Promise.all([loadPublicPlans(), loadHomeMerch()]);
    initScrollNav();
    initHeroMotion();
    initHeroVideo();
    bindInstagramLinks();
    initRevealMotion();
  } catch (error) {
    console.error('Error cargando portada:', error);
  }
}

loadHomeSections();
