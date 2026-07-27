function escBonos(str) {
  return String(str ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function formatBonosPlanPrice(b) {
  const n = Number(b.precio || 0);
  const formatted = Number.isInteger(n)
    ? String(n)
    : n.toFixed(2).replace('.', ',');
  const monthly =
    ['mensual', 'trimestral'].includes(b.periodicidad) &&
    (b.sesiones == null || Number(b.sesiones) > 1);
  return monthly ? `${formatted} €/mes` : `${formatted} €`;
}

const BONOS_FALLBACK_PLANS = [
  {
    id: 'plan-prueba',
    web_tag: 'Primera experiencia',
    nombre: 'Clase de prueba',
    web_meta: null,
    precio: 25,
    sesiones: 1,
    periodicidad: 'unico',
    descripcion: 'Descubre la experiencia NŌVA antes de elegir tu plan. Disponible una única vez por persona.',
    highlights: [
      '1 sesión en el estudio',
      'Conoce el método y el espacio',
      'Sin compromiso de continuidad',
    ],
  },
  {
    id: 'plan-flow',
    web_tag: 'Flow 01',
    nombre: 'NŌVA FLOW',
    web_meta: '2 días / semana',
    precio: 145,
    sesiones: null,
    periodicidad: 'mensual',
    descripcion: 'Ideal para comenzar y crear una rutina constante con la flexibilidad que necesitas.',
    highlights: [
      '2 días por semana',
      'Rutina constante y flexible',
      'Ideal para empezar en NŌVA',
    ],
  },
  {
    id: 'plan-balance',
    web_tag: 'Flow 02',
    nombre: 'NŌVA BALANCE',
    web_meta: '3 días / semana',
    precio: 185,
    sesiones: null,
    periodicidad: 'mensual',
    descripcion: 'El equilibrio perfecto entre compromiso, progreso y tiempo para ti.',
    highlights: [
      '3 días por semana',
      'Progreso sostenido',
      'Equilibrio entre práctica y vida',
    ],
  },
  {
    id: 'plan-signature',
    web_tag: 'Flow 03',
    nombre: 'NŌVA SIGNATURE',
    web_meta: '5 días / semana',
    precio: 225,
    sesiones: null,
    periodicidad: 'mensual',
    descripcion: 'La experiencia más completa para integrar el movimiento en tu estilo de vida.',
    highlights: [
      '5 días por semana',
      'Máxima constancia',
      'La experiencia NŌVA más completa',
    ],
  },
];

let bonosCatalogByKey = new Map();
let planModalKey = null;

function planKey(p, index = 0) {
  return String(p.id || p.nombre || `plan-${index}`);
}

function indexBonosCatalog(plans) {
  bonosCatalogByKey = new Map();
  (plans || []).forEach((p, i) => {
    const key = planKey(p, i);
    bonosCatalogByKey.set(key, { ...p, id: key });
  });
}

function planHighlights(p) {
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

function renderBonosPlans(grid, plans) {
  if (!grid) return;
  indexBonosCatalog(plans);
  grid.innerHTML = plans
    .map((p, i) => {
      const key = planKey(p, i);
      return `
      <article class="card plan-card plan-card--clickable reveal" data-plan-key="${escBonos(key)}">
        <button type="button" class="plan-card-open" data-open-plan="${escBonos(key)}" aria-label="Ver ${escBonos(p.nombre || 'plan')}">
          <p class="plan-tag">${escBonos(p.web_tag || 'Plan')}</p>
          <h3 class="plan-title">${escBonos(p.nombre)}</h3>
          ${p.web_meta ? `<p class="plan-meta">${escBonos(p.web_meta)}</p>` : ''}
          <p class="plan-price">${escBonos(formatBonosPlanPrice(p))}</p>
          <p class="plan-card-desc">${escBonos(p.descripcion || '')}</p>
          <span class="plan-card-more">Ver detalle</span>
        </button>
      </article>`;
    })
    .join('');
}

function ensurePlanModal() {
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

function isPlanModalOpen() {
  const modal = document.getElementById('planModal');
  return Boolean(modal && !modal.hidden);
}

function openPlanModal(key) {
  const plan = bonosCatalogByKey.get(key);
  if (!plan) return;
  ensurePlanModal();
  planModalKey = key;

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
  if (price) price.textContent = formatBonosPlanPrice(plan);
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
    const items = planHighlights(plan);
    list.innerHTML = items.map((item) => `<li>${escBonos(item)}</li>`).join('');
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

function closePlanModal() {
  const modal = document.getElementById('planModal');
  const backdrop = document.getElementById('planModalBackdrop');
  if (!modal || modal.hidden) return;
  modal.classList.remove('is-open');
  if (backdrop) backdrop.classList.remove('is-open');
  document.body.classList.remove('product-modal-open');
  window.setTimeout(() => {
    modal.hidden = true;
    if (backdrop) backdrop.hidden = true;
    planModalKey = null;
  }, 240);
}

function initPlanModalUi() {
  if (initPlanModalUi._ready) return;
  initPlanModalUi._ready = true;

  ensurePlanModal();
  document.getElementById('planModalClose')?.addEventListener('click', closePlanModal);
  document.getElementById('planModalBackdrop')?.addEventListener('click', closePlanModal);

  document.getElementById('plansGrid')?.addEventListener('click', (e) => {
    const t = e.target;
    if (!(t instanceof Element)) return;
    const key = t.closest('[data-open-plan]')?.getAttribute('data-open-plan');
    if (key) openPlanModal(key);
  });

  document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && isPlanModalOpen()) closePlanModal();
  });
}

async function loadBonosPlans() {
  const grid = document.getElementById('plansGrid');
  if (!grid) return;

  if (typeof novaSupabase === 'undefined') {
    renderBonosPlans(grid, BONOS_FALLBACK_PLANS);
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
      renderBonosPlans(grid, BONOS_FALLBACK_PLANS);
      return;
    }
    renderBonosPlans(grid, data);
  } catch (err) {
    console.warn('Planes web:', err);
    renderBonosPlans(grid, BONOS_FALLBACK_PLANS);
  }
}

function initBonosMotion() {
  const nav = document.querySelector('.nav');
  const onScroll = () => {
    if (!nav) return;
    nav.classList.toggle('is-scrolled', window.scrollY > 12);
  };
  onScroll();
  window.addEventListener('scroll', onScroll, { passive: true });

  const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
  const nodes = document.querySelectorAll('.reveal');
  if (reduce || !('IntersectionObserver' in window)) {
    nodes.forEach((n) => n.classList.add('is-in'));
    return;
  }
  const io = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        if (entry.isIntersecting) {
          entry.target.classList.add('is-in');
          io.unobserve(entry.target);
        }
      });
    },
    { rootMargin: '0px 0px -8% 0px', threshold: 0.12 }
  );
  nodes.forEach((n) => io.observe(n));
}

async function loadBonosPage() {
  const root = document.getElementById('page-root');
  if (!root) return;
  try {
    const response = await fetch('sections/bonos_zen.html');
    if (!response.ok) throw new Error('No se pudo cargar bonos.');
    root.innerHTML = await response.text();
    await loadBonosPlans();
    document.querySelectorAll('#plansGrid .plan-card').forEach((card, i) => {
      card.classList.add('reveal');
      card.style.setProperty('--reveal-delay', `${i * 80}ms`);
    });
    initPlanModalUi();
    initBonosMotion();
  } catch (err) {
    console.error(err);
    root.innerHTML =
      '<div class="container" style="padding:6rem 2rem"><p>No se pudo cargar los bonos. Recarga la página.</p></div>';
  }
}

document.addEventListener('DOMContentLoaded', loadBonosPage);
