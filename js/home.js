function escHome(str) {
  return String(str ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function formatPlanPrice(b) {
  const n = Number(b.precio || 0);
  const formatted = Number.isInteger(n)
    ? String(n)
    : n.toFixed(2).replace('.', ',');
  const monthly =
    ['mensual', 'trimestral'].includes(b.periodicidad) &&
    (b.sesiones == null || Number(b.sesiones) > 1);
  return monthly ? `${formatted} €/mes` : `${formatted} €`;
}

function renderPlansFallback(grid) {
  if (!grid) return;
  const plans = [
    {
      id: 'plan-prueba',
      web_tag: 'Primera experiencia',
      nombre: 'Clase de prueba',
      web_meta: null,
      precio: 25,
      sesiones: 1,
      periodicidad: 'unico',
      descripcion: 'Descubre la experiencia NŌVA antes de elegir tu plan. Disponible una única vez por persona.',
      highlights: ['1 sesión en el estudio', 'Conoce el método y el espacio', 'Sin compromiso de continuidad'],
    },
    {
      id: 'plan-flow',
      web_tag: 'Flow 01',
      nombre: 'NŌVA FLOW',
      web_meta: '2 días / semana',
      precio: 145,
      periodicidad: 'mensual',
      descripcion: 'Ideal para comenzar y crear una rutina constante con la flexibilidad que necesitas.',
      highlights: ['2 días por semana', 'Rutina constante y flexible', 'Ideal para empezar en NŌVA'],
    },
    {
      id: 'plan-balance',
      web_tag: 'Flow 02',
      nombre: 'NŌVA BALANCE',
      web_meta: '3 días / semana',
      precio: 185,
      periodicidad: 'mensual',
      descripcion: 'El equilibrio perfecto entre compromiso, progreso y tiempo para ti.',
      highlights: ['3 días por semana', 'Progreso sostenido', 'Equilibrio entre práctica y vida'],
    },
    {
      id: 'plan-signature',
      web_tag: 'Flow 03',
      nombre: 'NŌVA SIGNATURE',
      web_meta: '5 días / semana',
      precio: 225,
      periodicidad: 'mensual',
      descripcion: 'La experiencia más completa para integrar el movimiento en tu estilo de vida.',
      highlights: ['5 días por semana', 'Máxima constancia', 'La experiencia NŌVA más completa'],
    },
  ];
  renderHomePlans(grid, plans);
}

let homePlansByKey = new Map();

function homePlanKey(p, index = 0) {
  return String(p.id || p.nombre || `plan-${index}`);
}

function indexHomePlans(plans) {
  homePlansByKey = new Map();
  (plans || []).forEach((p, i) => {
    const key = homePlanKey(p, i);
    homePlansByKey.set(key, { ...p, id: key });
  });
}

function homePlanHighlights(p) {
  if (Array.isArray(p.highlights) && p.highlights.length) return p.highlights;
  const list = [];
  if (p.web_meta) list.push(p.web_meta);
  if (p.sesiones != null && Number(p.sesiones) > 0) {
    list.push(`${p.sesiones} ${Number(p.sesiones) === 1 ? 'sesión' : 'sesiones'}`);
  }
  if (p.periodicidad === 'mensual') list.push('Renovación mensual');
  if (p.periodicidad === 'trimestral') list.push('Renovación trimestral');
  if (p.periodicidad === 'unico' || p.periodicidad === 'único') list.push('Pago único');
  return list;
}

function renderHomePlans(grid, plans) {
  if (!grid) return;
  indexHomePlans(plans);
  grid.innerHTML = plans
    .map((p, i) => {
      const key = homePlanKey(p, i);
      return `
      <article class="card plan-card plan-card--clickable" data-plan-key="${escHome(key)}">
        <button type="button" class="plan-card-open" data-open-plan="${escHome(key)}" aria-label="Ver ${escHome(p.nombre || 'plan')}">
          <p class="plan-tag">${escHome(p.web_tag || 'Plan')}</p>
          <h3 class="plan-title">${escHome(p.nombre)}</h3>
          ${p.web_meta ? `<p class="plan-meta">${escHome(p.web_meta)}</p>` : ''}
          <p class="plan-price">${escHome(formatPlanPrice(p))}</p>
          <p class="plan-card-desc">${escHome(p.descripcion || '')}</p>
          <span class="plan-card-more">Ver detalle</span>
        </button>
      </article>`;
    })
    .join('');
  initHomePlanModalUi();
}

function ensureHomePlanModal() {
  if (document.getElementById('planModal')) return;
  const wrap = document.createElement('div');
  wrap.innerHTML = `
    <div class="product-modal-backdrop" id="planModalBackdrop" hidden></div>
    <div class="product-modal plan-modal" id="planModal" role="dialog" aria-modal="true" aria-labelledby="planModalTitle" hidden>
      <div class="product-modal-layout plan-modal-layout">
        <button type="button" class="product-modal-close" id="planModalClose" aria-label="Cerrar">×</button>
        <div class="plan-modal-visual" aria-hidden="true">
          <p class="plan-modal-visual-tag" id="planModalVisualTag"></p>
          <p class="plan-modal-visual-mark">NŌVA</p>
          <p class="plan-modal-visual-name" id="planModalVisualName"></p>
        </div>
        <div class="product-modal-info plan-modal-info">
          <p class="product-modal-tag" id="planModalTag"></p>
          <h2 class="product-modal-title" id="planModalTitle"></h2>
          <p class="product-modal-price" id="planModalPrice"></p>
          <p class="plan-modal-meta" id="planModalMeta" hidden></p>
          <p class="product-modal-desc" id="planModalDesc"></p>
          <ul class="plan-modal-list" id="planModalList"></ul>
          <a class="btn btn-primary product-modal-cta" id="planModalCta" href="login.html">Empezar en NŌVA</a>
        </div>
      </div>
    </div>`;
  while (wrap.firstChild) document.body.appendChild(wrap.firstChild);
}

function openHomePlanModal(key) {
  const plan = homePlansByKey.get(key);
  if (!plan) return;
  ensureHomePlanModal();
  const tag = document.getElementById('planModalTag');
  const title = document.getElementById('planModalTitle');
  const price = document.getElementById('planModalPrice');
  const desc = document.getElementById('planModalDesc');
  const meta = document.getElementById('planModalMeta');
  const list = document.getElementById('planModalList');
  const visualTag = document.getElementById('planModalVisualTag');
  const visualName = document.getElementById('planModalVisualName');
  if (tag) tag.textContent = plan.web_tag || 'Plan';
  if (title) title.textContent = plan.nombre || '';
  if (price) price.textContent = formatPlanPrice(plan);
  if (desc) desc.textContent = plan.descripcion || '';
  if (visualTag) visualTag.textContent = plan.web_tag || 'Plan';
  if (visualName) visualName.textContent = plan.nombre || '';
  if (meta) {
    if (plan.web_meta) {
      meta.hidden = false;
      meta.textContent = plan.web_meta;
    } else {
      meta.hidden = true;
      meta.textContent = '';
    }
  }
  if (list) {
    const items = homePlanHighlights(plan);
    list.innerHTML = items.map((item) => `<li>${escHome(item)}</li>`).join('');
    list.hidden = !items.length;
  }
  const modal = document.getElementById('planModal');
  const backdrop = document.getElementById('planModalBackdrop');
  if (!modal) return;
  modal.hidden = false;
  if (backdrop) backdrop.hidden = false;
  document.body.classList.add('product-modal-open');
  requestAnimationFrame(() => {
    modal.classList.add('is-open');
    if (backdrop) backdrop.classList.add('is-open');
  });
  document.getElementById('planModalClose')?.focus();
}

function closeHomePlanModal() {
  const modal = document.getElementById('planModal');
  const backdrop = document.getElementById('planModalBackdrop');
  if (!modal || modal.hidden) return;
  modal.classList.remove('is-open');
  if (backdrop) backdrop.classList.remove('is-open');
  document.body.classList.remove('product-modal-open');
  window.setTimeout(() => {
    modal.hidden = true;
    if (backdrop) backdrop.hidden = true;
  }, 240);
}

function initHomePlanModalUi() {
  if (initHomePlanModalUi._ready) return;
  initHomePlanModalUi._ready = true;
  ensureHomePlanModal();
  document.getElementById('planModalClose')?.addEventListener('click', closeHomePlanModal);
  document.getElementById('planModalBackdrop')?.addEventListener('click', closeHomePlanModal);
  document.getElementById('plansGrid')?.addEventListener('click', (e) => {
    const t = e.target;
    if (!(t instanceof Element)) return;
    const key = t.closest('[data-open-plan]')?.getAttribute('data-open-plan');
    if (key) openHomePlanModal(key);
  });
  document.addEventListener('keydown', (e) => {
    const modal = document.getElementById('planModal');
    if (e.key === 'Escape' && modal && !modal.hidden) closeHomePlanModal();
  });
}

async function loadPublicPlans() {
  const grid = document.getElementById('plansGrid');
  if (!grid || typeof novaSupabase === 'undefined') {
    renderPlansFallback(grid);
    return;
  }
  try {
    const { data, error } = await novaSupabase
      .from('tipos_bono')
      .select('id,nombre,descripcion,precio,sesiones,periodicidad,orden,web_tag,web_meta')
      .eq('visible_web', true)
      .eq('activo', true)
      .order('orden', { ascending: true });
    if (error) throw error;
    if (!data || !data.length) {
      renderPlansFallback(grid);
      return;
    }
    renderHomePlans(grid, data);
  } catch (err) {
    console.warn('Planes web:', err);
    renderPlansFallback(grid);
  }
}

const HOME_MERCH_PREVIEW = [
  {
    id: 'preview-botella',
    title: 'Botella NŌVA',
    description: 'Hidratación ligera para antes y después de clase.',
    thumbnail: '/assets/shop/botella-nova.png',
    price: 28,
    currency: 'eur',
    collection: 'Accesorios',
  },
  {
    id: 'preview-tote',
    title: 'Tote Studio',
    description: 'Bolsa de lona para esterilla, muda y lo esencial.',
    thumbnail: '/assets/shop/tote-studio.png',
    price: 32,
    currency: 'eur',
    collection: 'Accesorios',
  },
  {
    id: 'preview-camiseta',
    title: 'Camiseta técnica',
    description: 'Tejido moisture-wicking y quick-dry, marca discreta.',
    thumbnail: '/assets/shop/camiseta-tecnica.png',
    price: 38,
    currency: 'eur',
    collection: 'Ropa',
  },
  {
    id: 'preview-banda',
    title: 'Banda de resistencia',
    description: 'Loop de tela, resistencia media. Para suelo o casa.',
    thumbnail: '/assets/shop/banda-resistencia.png',
    price: 18,
    currency: 'eur',
    collection: 'Movimiento',
  },
];

function formatHomeMerchPrice(amount, currency) {
  if (amount == null || Number.isNaN(Number(amount))) return '—';
  const n = Number(amount);
  const formatted = Number.isInteger(n)
    ? String(n)
    : n.toFixed(2).replace('.', ',');
  const cur = String(currency || 'eur').toLowerCase();
  if (cur === 'eur') return `${formatted} €`;
  return `${formatted} ${cur.toUpperCase()}`;
}

function renderHomeMerch(grid, products) {
  if (!grid) return;
  const list = (products || []).slice(0, 4);
  grid.innerHTML = list
    .map((p) => {
      const tag = p.collection || 'Merch';
      const media = p.thumbnail
        ? `<img class="shop-card-img" src="${escHome(p.thumbnail)}" alt="" loading="lazy" decoding="async" />`
        : `<div class="shop-card-placeholder" aria-hidden="true"><span>${escHome((p.title || 'N').charAt(0))}</span></div>`;
      return `
      <a class="shop-card" href="tienda.html">
        <div class="shop-card-media">${media}</div>
        <div class="shop-card-body">
          <p class="shop-card-tag">${escHome(tag)}</p>
          <h3 class="shop-card-title">${escHome(p.title)}</h3>
          <p class="shop-card-price">${escHome(formatHomeMerchPrice(p.price, p.currency))}</p>
          <p class="shop-card-desc">${escHome(p.description || '')}</p>
        </div>
      </a>`;
    })
    .join('');
}

async function loadHomeMerch() {
  const grid = document.getElementById('homeShopGrid');
  if (!grid) return;
  if (typeof medusaIsConfigured === 'function' && medusaIsConfigured()) {
    try {
      const products = await medusaListProducts();
      if (products.length) {
        renderHomeMerch(grid, products);
        return;
      }
    } catch (err) {
      console.warn('Merch home:', err);
    }
  }
  renderHomeMerch(grid, HOME_MERCH_PREVIEW);
}

function prefersReducedMotion() {
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

function markReveal(el, delayMs = 0) {
  if (!el || el.classList.contains('reveal')) return;
  el.classList.add('reveal');
  if (delayMs) el.style.setProperty('--reveal-delay', `${delayMs}ms`);
}

function initScrollNav() {
  const nav = document.querySelector('.nav');
  if (!nav) return;
  const onScroll = () => {
    nav.classList.toggle('is-scrolled', window.scrollY > 12);
  };
  onScroll();
  window.addEventListener('scroll', onScroll, { passive: true });
}

function initHeroMotion() {
  const copy = document.querySelector('.hero-copy');
  if (!copy) return;
  if (prefersReducedMotion()) {
    copy.classList.add('is-ready');
    return;
  }
  requestAnimationFrame(() => {
    requestAnimationFrame(() => copy.classList.add('is-ready'));
  });
}

function initRevealMotion() {
  const root = document.getElementById('page-root');
  if (!root) return;

  const singles = root.querySelectorAll(
    '.empezar-copy, .empezar-btn, .section-head-center, .plans-head, .pillars-foot, .plans-cta, .plans-slogan, .merch-head, .merch-cta, .section-donde-inner, .cta .container > *'
  );
  singles.forEach((el, i) => markReveal(el, Math.min(i * 40, 160)));

  root.querySelectorAll('.pillars-grid, .steps-pillars, .plans-grid, .merch-home-grid').forEach((grid) => {
    [...grid.children].forEach((child, i) => markReveal(child, i * 90));
  });

  const nodes = root.querySelectorAll('.reveal');
  if (!nodes.length) return;

  if (prefersReducedMotion() || !('IntersectionObserver' in window)) {
    nodes.forEach((n) => n.classList.add('is-in'));
    return;
  }

  const io = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (!entry.isIntersecting) return;
        entry.target.classList.add('is-in');
        io.unobserve(entry.target);
      });
    },
    { root: null, rootMargin: '0px 0px -8% 0px', threshold: 0.12 }
  );

  nodes.forEach((n) => io.observe(n));
}

function initHomeMotion() {
  document.documentElement.classList.add('js-motion');
  initScrollNav();
  initHeroMotion();
  initRevealMotion();
}

async function loadHomeSections() {
  const root = document.getElementById('page-root');
  if (!root) return;

  try {
    const response = await fetch('sections/home_zen.html');
    if (!response.ok) throw new Error('No se pudo cargar la home.');
    root.innerHTML = await response.text();
    await Promise.all([loadPublicPlans(), loadHomeMerch()]);
    initHomeMotion();
  } catch (error) {
    root.innerHTML = `
      <section class="section">
        <div class="container">
          <h1 style="font-family: var(--font-display); margin-bottom: 1rem;">NŌVA PILATES STUDIO</h1>
          <p>No se pudo cargar la portada. Revisa el archivo <code>sections/home_zen.html</code>.</p>
        </div>
      </section>
    `;
    console.error(error);
  }
}

loadHomeSections();
